const axios = require('axios');
const c6bankAuth = require('./c6bank-auth');
require('dotenv').config();

/**
 * Módulo para interagir com a API PIX do C6 Bank
 * Implementa criação, consulta e gerenciamento de cobranças PIX
 */
class C6BankPix {
    constructor() {
        this.pixKey = process.env.C6BANK_PIX_KEY;
    }

    /**
     * Obtém a URL base da API PIX
     */
    getApiUrl() {
        return c6bankAuth.getApiBaseUrl() + '/v2/pix';
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

                // Salvar erro em arquivo para debug
                const fs = require('fs');
                try {
                    fs.writeFileSync('debug_c6_pix_error.json', JSON.stringify({
                        status: error.response.status,
                        data: error.response.data,
                        headers: error.response.headers,
                        payloadSent: data
                    }, null, 2));
                } catch (err) {
                    console.error('Erro ao salvar arquivo de debug:', err);
                }

                console.error('   Dados:', JSON.stringify(error.response.data, null, 2));

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
     * Cria uma cobrança PIX imediata
     * @param {object} params - Parâmetros da cobrança
     * @param {string} params.txid - ID da transação (único)
     * @param {string} params.amount - Valor em formato string (ex: "197.00")
     * @param {string} params.payerName - Nome do pagador
     * @param {string} params.payerCpf - CPF do pagador (apenas números)
     * @param {string} params.description - Descrição do pagamento
     * @param {number} params.expiration - Tempo de expiração em segundos (padrão: 3600)
     * @returns {Promise<object>} Dados da cobrança criada
     */
    async createCharge(params) {
        const {
            txid,
            amount,
            payerName,
            payerCpf,
            description,
            expiration = 3600
        } = params;

        console.log('💳 Criando cobrança PIX C6 Bank:');
        console.log('   TXID:', txid);
        console.log('   Valor:', amount);
        console.log('   Pagador:', payerName);

        // Validar CPF (apenas números, 11 dígitos)
        const cpfClean = (payerCpf || '').replace(/\D/g, '');
        if (cpfClean.length !== 11) {
            console.warn('⚠️ CPF inválido, usando CPF padrão para sandbox');
        }

        const payload = {
            calendario: {
                expiracao: expiration
            },
            devedor: {
                cpf: cpfClean.length === 11 ? cpfClean : '12345678909', // CPF padrão para testes
                nome: payerName || 'Cliente'
            },
            valor: {
                original: amount
            },
            chave: this.pixKey,
            solicitacaoPagador: description || 'Pagamento PIX'
        };

        console.log('📦 Payload:', JSON.stringify(payload, null, 2));

        // PUT /v2/pix/cob/{txid}
        const result = await this.makeRequest('PUT', `/cob/${txid}`, payload);

        console.log('✅ Cobrança criada com sucesso');
        console.log('   Location:', result.location);
        console.log('   Status:', result.status);

        return {
            txid: result.txid,
            status: result.status,
            pixCopiaECola: result.pixCopiaECola,
            location: result.location,
            createdAt: result.calendario?.criacao,
            expiresAt: result.calendario?.expiracao,
            amount: result.valor?.original,
            imageQrCode: result.qrcode || null // Alguns ambientes retornam a imagem do QR
        };
    }

    /**
     * Consulta uma cobrança PIX existente
     * @param {string} txid - ID da transação
     * @returns {Promise<object>} Dados da cobrança
     */
    async getCharge(txid) {
        console.log('🔍 Consultando cobrança:', txid);

        // GET /v2/pix/cob/{txid}
        const result = await this.makeRequest('GET', `/cob/${txid}`);

        console.log('✅ Cobrança encontrada');
        console.log('   Status:', result.status);

        // Verificar se há pagamento
        if (result.pix && result.pix.length > 0) {
            console.log('💰 Pagamento(s) recebido(s):', result.pix.length);
            result.pix.forEach(p => {
                console.log('   End-to-End:', p.endToEndId);
                console.log('   Valor:', p.valor);
                console.log('   Horário:', p.horario);
            });
        }

        return {
            txid: result.txid,
            status: result.status,
            pixCopiaECola: result.pixCopiaECola,
            amount: result.valor?.original,
            createdAt: result.calendario?.criacao,
            // Lista de pagamentos recebidos (pode ter mais de um)
            payments: result.pix || [],
            // Informações do devedor
            debtor: result.devedor
        };
    }

    /**
     * Atualiza/revisa uma cobrança existente
     * @param {string} txid - ID da transação
     * @param {object} updates - Campos a atualizar
     * @returns {Promise<object>} Dados atualizados
     */
    async updateCharge(txid, updates) {
        console.log('✏️ Atualizando cobrança:', txid);

        // PATCH /pix/v1/cob/{txid}
        const result = await this.makeRequest('PATCH', `/pix/v1/cob/${txid}`, updates);

        console.log('✅ Cobrança atualizada');
        return result;
    }

    /**
     * Lista cobranças com filtros opcionais
     * @param {object} filters - Filtros de busca
     * @returns {Promise<object>} Lista de cobranças
     */
    async listCharges(filters = {}) {
        console.log('📋 Listando cobranças...');

        // GET /pix/v1/cob?inicio=...&fim=...
        const queryParams = new URLSearchParams(filters).toString();
        const endpoint = `/pix/v1/cob${queryParams ? '?' + queryParams : ''}`;

        const result = await this.makeRequest('GET', endpoint);

        console.log('✅ Cobranças listadas:', result.cobs?.length || 0);
        return result;
    }

    /**
     * Verifica se uma cobrança foi paga
     * @param {string} txid - ID da transação
     * @returns {Promise<boolean>} True se pago, false caso contrário
     */
    async isChargePaid(txid) {
        try {
            const charge = await this.getCharge(txid);

            // Status CONCLUIDA significa que foi pago
            if (charge.status === 'CONCLUIDA') {
                return true;
            }

            // Ou verificar se há pagamentos na lista
            if (charge.payments && charge.payments.length > 0) {
                return true;
            }

            return false;

        } catch (error) {
            console.error('❌ Erro ao verificar pagamento:', error.message);
            return false;
        }
    }
}

// Singleton
const pixInstance = new C6BankPix();

module.exports = pixInstance;
