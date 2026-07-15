const axios = require('axios');
const c6bankAuth = require('./c6bank-auth');
require('dotenv').config();

/**
 * Módulo para processar pagamentos com cartão via C6 Bank Checkout
 * API: /v1/checkouts
 */
class C6BankCheckout {
    constructor() {
        // Configurações serão carregadas do banco ou .env
    }

    /**
     * Obtém a URL base da API de Checkout
     */
    getApiUrl() {
        return c6bankAuth.getApiBaseUrl() + '/v1/checkouts';
    }

    /**
     * Cria uma requisição autenticada para a API do C6 Bank
     */
    async makeRequest(method, endpoint, data = null) {
        try {
            const token = await c6bankAuth.getValidToken();
            const apiUrl = this.getApiUrl();

            const config = {
                method,
                url: `${apiUrl}${endpoint}`,
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                },
                timeout: 15000
            };

            // Adicionar agente HTTPS com certificados mTLS
            const httpsAgent = c6bankAuth.createHttpsAgent();
            if (httpsAgent) {
                config.httpsAgent = httpsAgent;
            }

            if (data) {
                config.data = data;
            }

            const response = await axios(config);
            return response.data;

        } catch (error) {
            console.error(`❌ Erro na requisição ${method} ${endpoint}:`, error.message);
            if (data) console.error('   Payload enviado:', JSON.stringify(data, null, 2));

            if (error.response) {
                console.error('   Status:', error.response.status);
                // Salvar erro em arquivo para debug
                const fs = require('fs');
                fs.writeFileSync('debug_c6_error.json', JSON.stringify({
                    status: error.response.status,
                    data: error.response.data,
                    headers: error.response.headers,
                    payloadSent: data
                }, null, 2));

                console.error('   Dados:', JSON.stringify(error.response.data, null, 2));

                if (error.response.status === 401) {
                    console.log('🔄 Token inválido, renovando...');
                    c6bankAuth.invalidateToken();
                    const newToken = await c6bankAuth.getValidToken();
                    config.headers['Authorization'] = `Bearer ${newToken}`;
                    const retryResponse = await axios(config);
                    return retryResponse.data;
                }
            }

            throw error;
        }
    }

    /**
     * Cria uma sessão de checkout para pagamento com cartão
     * @param {object} params - Parâmetros do checkout
     * @param {number} params.amount - Valor em centavos
     * @param {string} params.description - Descrição da compra
     * @param {string} params.orderId - ID do pedido (referência externa)
     * @param {object} params.customer - Dados do cliente
     * @param {string} params.returnUrl - URL de retorno após pagamento
     * @param {string} params.callbackUrl - URL para webhook
     * @param {number} params.installments - Número de parcelas (padrão: 1)
     * @returns {Promise<object>} Dados da sessão de checkout
     */
    async createCheckout(params) {
        const {
            amount,
            description,
            orderId,
            customer,
            returnUrl,
            callbackUrl,
            installments = 1,
            // Novos dados opcionais de cartão (se vierem do front)
            cardNumber,
            cardExpiry, // "MM/AA"
            cardCvv,
            cardName
        } = params;

        console.log('💳 Processando checkout C6 Bank:');
        console.log('   Valor: R$', (amount / 100).toFixed(2));
        console.log('   Tipo: ', cardNumber ? 'Transparente (Dados Recebidos)' : 'Link de Pagamento');

        const payload = {
            amount: amount / 100,
            description: description || 'Pagamento de pedido',
            // external_reference_id: max 10 chars, alphanumeric
            external_reference_id: orderId.toString().substring(0, 10),
            payer: {
                name: customer.name.substring(0, 50),
                tax_id: customer.document.replace(/\D/g, ''),
                email: customer.email,
                phone_number: customer.phone ? customer.phone.replace(/\D/g, '') : null,
                address: {
                    street: (customer.address.street || 'Rua não informada').substring(0, 40),
                    number: parseInt(customer.address.number) || 1,
                    complement: customer.address.complement ? customer.address.complement.substring(0, 30) : undefined,
                    // district removido pois não é aceito pela API
                    city: (customer.address.city || 'Cidade não informada').substring(0, 30),
                    state: (customer.address.state || 'SP').toUpperCase().substring(0, 2),
                    zip_code: customer.address.zipCode ? customer.address.zipCode.replace(/\D/g, '') : '00000000'
                }
            },
            payment: {
                // Configuração básica para checkout hospedado
                // Se não enviarmos card_info.token, o C6 deve solicitar os dados no redirecionamento
                card: {
                    authenticate: "NOT_REQUIRED",
                    capture: true,
                    fixed_installments: true,
                    installments: installments,
                    interest_type: "BY_SELLER",
                    recurrent: false,
                    save_card: false,
                    type: "CREDIT"
                },
                // Link de pagamento híbrido (Card + Pix na mesma tela do C6)
                pix: {
                    key: "AUTO"
                }
            },
            redirect_url: returnUrl
        };

        // NOTA: Para checkout transparente real, a API exige 'card_info.token'.
        // Como não temos o endpoint de tokenização documentado/implementado,
        // usamos o modo Hosted Checkout (Redirecionamento) que aceita essa configuração.
        // Dados de cartão recebidos (se houver) são ignorados em favor do ambiente seguro C6.

        console.log('📦 Payload:', JSON.stringify(payload, null, 2));

        // POST /v1/checkouts (Criação de Link)
        const result = await this.makeRequest('POST', '', payload);

        console.log('✅ Checkout criado/autorizado');

        return {
            id: result.id,
            checkoutUrl: result.url || result.checkout_url,
            status: result.status,
            amount: result.amount
        };
    }

    /**
     * Consulta o status de um checkout
     * @param {string} checkoutId - ID do checkout
     * @returns {Promise<object>} Dados do checkout
     */
    async getCheckout(checkoutId) {
        console.log('🔍 Consultando checkout:', checkoutId);

        // GET /v1/checkouts/{id}
        const result = await this.makeRequest('GET', `/${checkoutId}`);

        console.log('✅ Checkout encontrado');
        console.log('   Status:', result.status);

        return {
            id: result.id,
            status: result.status,
            amount: result.amount,
            externalReference: result.external_reference,
            payment: result.payment || null,
            createdAt: result.created_at,
            updatedAt: result.updated_at
        };
    }

    /**
     * Captura uma transação pré-autorizada
     * @param {string} checkoutId - ID do checkout
     * @param {number} amount - Valor a capturar (opcional, padrão: valor total)
     * @returns {Promise<object>} Confirmação da captura
     */
    async captureCheckout(checkoutId, amount = null) {
        console.log('💰 Capturando checkout:', checkoutId);

        const payload = amount ? { amount } : {};

        // PUT /v1/checkouts/{id}/capture
        const result = await this.makeRequest('PUT', `/${checkoutId}/capture`, payload);

        console.log('✅ Checkout capturado');
        return result;
    }

    /**
     * Verifica se um checkout foi pago
     * @param {string} checkoutId - ID do checkout
     * @returns {Promise<boolean>} True se pago, false caso contrário
     */
    async isCheckoutPaid(checkoutId) {
        try {
            const checkout = await this.getCheckout(checkoutId);
            return checkout.status === 'PAID' || checkout.status === 'APPROVED';
        } catch (error) {
            console.error('❌ Erro ao verificar pagamento:', error.message);
            return false;
        }
    }

    /**
     * Cancela um checkout
     * @param {string} checkoutId - ID do checkout
     * @returns {Promise<object>} Confirmação do cancelamento
     */
    async cancelCheckout(checkoutId) {
        console.log('❌ Cancelando checkout:', checkoutId);

        // PUT /v1/checkouts/{id}/cancel
        const result = await this.makeRequest('PUT', `/${checkoutId}/cancel`);

        console.log('✅ Checkout cancelado');
        return result;
    }
}

// Singleton
const checkoutInstance = new C6BankCheckout();

module.exports = checkoutInstance;
