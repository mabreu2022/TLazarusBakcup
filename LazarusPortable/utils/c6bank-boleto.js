const axios = require('axios');
const c6bankAuth = require('./c6bank-auth');
require('dotenv').config();

/**
 * Módulo para geração e gestão de boletos bancários via C6 Bank
 * API: /v1/bank_slips
 */
class C6BankBoleto {
    constructor() {
        // Configurações serão carregadas do banco ou .env
    }

    /**
     * Obtém a URL base da API de Boletos
     */
    getApiUrl() {
        return c6bankAuth.getApiBaseUrl() + '/v1/bank_slips';
    }

    /**
     * Cria uma requisição autenticada para a API do C6 Bank
     * @param {string} method - Método HTTP
     * @param {string} endpoint - Endpoint da API
     * @param {object} data - Dados do corpo da requisição
     * @returns {Promise<object>} Resposta da API
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

            if (error.response) {
                console.error('   Status:', error.response.status);
                console.error('   Status Text:', error.response.statusText);
                console.error('   Dados:', JSON.stringify(error.response.data, null, 2));
                console.error('   Headers:', JSON.stringify(error.response.headers, null, 2));

                // Salvar erro em arquivo para debug
                const fs = require('fs');
                try {
                    fs.writeFileSync('debug_c6_boleto_error.json', JSON.stringify({
                        status: error.response.status,
                        data: error.response.data,
                        headers: error.response.headers,
                        payloadSent: data
                    }, null, 2));
                } catch (err) {
                    console.error('Erro ao salvar arquivo de debug:', err);
                }

                // Se erro 401, invalida token e tenta novamente
                if (error.response.status === 401) {
                    console.log('🔄 Token inválido, renovando e tentando novamente...');
                    c6bankAuth.invalidateToken();

                    // Tenta uma vez apenas para evitar loop infinito
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
     * Gera um novo boleto bancário
     * @param {object} params - Parâmetros do boleto
     * @param {number} params.amount - Valor do boleto em centavos
     * @param {string} params.dueDate - Data de vencimento (YYYY-MM-DD)
     * @param {object} params.payer - Dados do pagador
     * @param {string} params.payer.name - Nome do pagador
     * @param {string} params.payer.document - CPF/CNPJ do pagador
     * @param {string} params.payer.email - Email do pagador
     * @param {object} params.payer.address - Endereço do pagador
     * @param {string} params.description - Descrição do boleto
     * @param {number} params.fine - Multa após vencimento (percentual)
     * @param {number} params.interest - Juros por dia (percentual)
     * @param {number} params.discount - Desconto até data (percentual)
     * @returns {Promise<object>} Dados do boleto gerado
     */
    async generateBoleto(params) {
        const {
            amount,
            dueDate,
            payer
        } = params;

        console.log('💳 Gerando boleto C6 Bank (payload mínimo):');
        console.log('   Valor: R$', (amount / 100).toFixed(2));
        console.log('   Vencimento:', dueDate);
        console.log('   Pagador:', payer.name);

        // Gerar external_reference_id único (max 10 caracteres alfanuméricos)
        const externalRef = `ORD${Date.now().toString().slice(-7)}`;

        // Payload MÍNIMO com apenas campos obrigatórios
        const payload = {
            external_reference_id: externalRef,
            amount: amount / 100, // API espera valor em reais
            due_date: dueDate,
            payer: {
                name: payer.name.substring(0, 40),
                tax_id: payer.document.replace(/\D/g, ''),
                address: {
                    street: payer.address.street.substring(0, 33),
                    number: parseInt(payer.address.number) || 1,
                    city: payer.address.city.substring(0, 40),
                    state: payer.address.state.toUpperCase().substring(0, 2),
                    zip_code: payer.address.zipCode.replace(/\D/g, '')
                }
            }
        };

        // Adicionar email se disponível (não obrigatório)
        if (payer.email) {
            payload.payer.email = payer.email;
        }

        // Adicionar complemento se disponível (não obrigatório)
        if (payer.address.complement) {
            payload.payer.address.complement = payer.address.complement.substring(0, 24);
        }

        console.log('📦 Payload MÍNIMO:', JSON.stringify(payload, null, 2));

        // POST /v1/bank_slips
        const result = await this.makeRequest('POST', '', payload);

        console.log('✅ Boleto gerado com sucesso');
        console.log('   ID:', result.id);
        console.log('   Código de barras:', result.bar_code);

        return {
            id: result.id,
            barcode: result.bar_code,
            digitableLine: result.digitable_line,
            dueDate: result.due_date,
            amount: result.amount,
            pdfUrl: result.base64_pdf_file ? `data:application/pdf;base64,${result.base64_pdf_file}` : null,
            status: result.status
        };
    }

    /**
     * Consulta um boleto existente
     * @param {string} boletoId - ID do boleto
     * @returns {Promise<object>} Dados do boleto
     */
    async getBoleto(boletoId) {
        console.log('🔍 Consultando boleto:', boletoId);

        // GET /v1/bank_slips/{id}
        const result = await this.makeRequest('GET', `/${boletoId}`);

        console.log('✅ Boleto encontrado');
        console.log('   Status:', result.status);

        return {
            id: result.id,
            barcode: result.bar_code,
            digitableLine: result.digitable_line,
            dueDate: result.due_date,
            amount: result.amount,
            pdfUrl: result.base64_pdf_file ? `data:application/pdf;base64,${result.base64_pdf_file}` : null,
            status: result.status,
            paidAt: result.payments && result.payments.length > 0 ? result.payments[0].date : null,
            paidAmount: result.payments && result.payments.length > 0 ? result.payments[0].amount : null
        };
    }

    /**
     * Obtém o PDF do boleto
     * @param {string} boletoId - ID do boleto
     * @returns {Promise<Buffer>} PDF do boleto
     */
    async getBoletoPDF(boletoId) {
        console.log('📄 Obtendo PDF do boleto:', boletoId);

        try {
            const token = await c6bankAuth.getValidToken();
            const apiUrl = this.getApiUrl();

            // GET /v1/bank_slips/{id}/pdf
            const response = await axios.get(
                `${apiUrl}/${boletoId}/pdf`,
                {
                    headers: {
                        'Authorization': `Bearer ${token}`
                    },
                    responseType: 'arraybuffer',
                    timeout: 20000
                }
            );

            console.log('✅ PDF obtido com sucesso');
            return response.data;

        } catch (error) {
            console.error('❌ Erro ao obter PDF:', error.message);
            throw error;
        }
    }

    /**
     * Cancela um boleto
     * @param {string} boletoId - ID do boleto
     * @returns {Promise<object>} Confirmação do cancelamento
     */
    async cancelBoleto(boletoId) {
        console.log('❌ Cancelando boleto:', boletoId);

        // PUT /v1/bank_slips/{id}/cancel
        const result = await this.makeRequest('PUT', `/${boletoId}/cancel`);

        console.log('✅ Boleto cancelado');
        return result;
    }

    /**
     * Verifica se um boleto foi pago
     * @param {string} boletoId - ID do boleto
     * @returns {Promise<boolean>} True se pago, false caso contrário
     */
    async isBoletoPaid(boletoId) {
        try {
            const boleto = await this.getBoleto(boletoId);
            return boleto.status === 'PAID' || boleto.status === 'SETTLED';
        } catch (error) {
            console.error('❌ Erro ao verificar pagamento:', error.message);
            return false;
        }
    }
}

// Singleton
const boletoInstance = new C6BankBoleto();

module.exports = boletoInstance;
