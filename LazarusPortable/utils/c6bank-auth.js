const axios = require('axios');
const https = require('https');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

/**
 * Módulo de Autenticação OAuth2 do C6 Bank
 * Gerencia tokens de acesso com renovação automática
 * Suporta mTLS com certificados digitais
 */
class C6BankAuth {
    constructor() {
        // Configurações padrão do .env
        this.clientId = process.env.C6BANK_CLIENT_ID;
        this.clientSecret = process.env.C6BANK_CLIENT_SECRET;
        this.environment = process.env.C6BANK_ENVIRONMENT || 'sandbox';

        // Caminhos dos certificados
        this.certPath = process.env.C6BANK_CERT_PATH || path.join(__dirname, '../c6 bank/Certificados/cert.crt');
        this.keyPath = process.env.C6BANK_KEY_PATH || path.join(__dirname, '../c6 bank/Certificados/cert.key');
        this.useMtls = process.env.C6BANK_USE_MTLS === 'true';

        // Cache do token
        this.accessToken = null;
        this.tokenExpiresAt = null;

        // Configurações carregadas do banco (se disponível)
        this.dbSettings = null;
    }

    /**
     * Carrega configurações do banco de dados
     * @param {object} db - Instância do banco de dados
     */
    async loadSettingsFromDB(db) {
        try {
            const settings = await db.get('SELECT * FROM c6bank_settings WHERE id = 1');

            if (settings && settings.enabled) {
                this.dbSettings = settings;
                this.clientId = settings.client_id || this.clientId;
                this.clientSecret = settings.client_secret || this.clientSecret;
                this.environment = settings.environment || this.environment;

                console.log('✅ Configurações C6 Bank carregadas do banco de dados');
                console.log('   Ambiente:', this.environment);

                return true;
            }

            return false;
        } catch (error) {
            console.warn('⚠️ Não foi possível carregar configurações do banco:', error.message);
            return false;
        }
    }

    /**
     * Obtém a URL de autenticação baseada no ambiente
     */
    getAuthUrl() {
        if (this.environment === 'production') {
            return 'https://baas-api.c6bank.info/v1/auth/';
        }
        return 'https://baas-api-sandbox.c6bank.info/v1/auth/';
    }

    /**
     * Obtém a URL base da API baseada no ambiente
     */
    getApiBaseUrl() {
        if (this.environment === 'production') {
            return 'https://baas-api.c6bank.info';
        }
        return 'https://baas-api-sandbox.c6bank.info';
    }

    /**
     * Cria um agente HTTPS com certificados mTLS se configurado
     */
    createHttpsAgent() {
        if (!this.useMtls) {
            return undefined;
        }

        try {
            // Verificar se os certificados existem
            if (!fs.existsSync(this.certPath)) {
                console.warn('⚠️ Certificado não encontrado:', this.certPath);
                return undefined;
            }

            if (!fs.existsSync(this.keyPath)) {
                console.warn('⚠️ Chave privada não encontrada:', this.keyPath);
                return undefined;
            }

            const cert = fs.readFileSync(this.certPath);
            const key = fs.readFileSync(this.keyPath);

            console.log('📄 Certificados carregados com sucesso');

            return new https.Agent({
                cert,
                key,
                // Em sandbox, muitas vezes é necessário ignorar erros de CA
                // Isso replica o comportamento do Postman com SSL Verification OFF
                rejectUnauthorized: this.environment === 'production',
                minVersion: 'TLSv1.2'
            });
        } catch (error) {
            console.error('❌ Erro ao carregar certificados:', error.message);
            return undefined;
        }
    }

    /**
     * Verifica se o módulo está configurado corretamente
     */
    isConfigured() {
        return !!(this.clientId && this.clientSecret);
    }

    /**
     * Autentica na API do C6 Bank e obtém token de acesso
     * @returns {Promise<string>} Token de acesso
     */
    async authenticate() {
        if (!this.isConfigured()) {
            throw new Error('C6 Bank não configurado. Verifique as credenciais.');
        }

        try {
            const authUrl = this.getAuthUrl();

            console.log('🔐 Autenticando no C6 Bank...');
            console.log('   Ambiente:', this.environment);
            console.log('   Auth URL:', authUrl);
            console.log('   mTLS:', this.useMtls ? 'Habilitado' : 'Desabilitado');

            // Gerar hash Basic Auth dinamicamente a partir das credenciais
            // Isso garante que se o .env mudar, a autenticação segue correta
            const credentials = `${this.clientId}:${this.clientSecret}`;
            const basicAuth = Buffer.from(credentials).toString('base64');

            // Preparar configuração da requisição
            const config = {
                headers: {
                    'Authorization': `Basic ${basicAuth}`,
                    'Content-Type': 'application/x-www-form-urlencoded'
                },
                timeout: 15000
            };

            // Adicionar agente HTTPS com certificados se mTLS estiver habilitado
            const httpsAgent = this.createHttpsAgent();
            if (httpsAgent) {
                config.httpsAgent = httpsAgent;
            }

            // Fazer requisição de autenticação
            const response = await axios.post(
                authUrl,
                'grant_type=client_credentials',
                config
            );

            if (!response.data || !response.data.access_token) {
                throw new Error('Resposta de autenticação inválida');
            }

            this.accessToken = response.data.access_token;

            // Define expiração (geralmente 600 segundos, com margem de 60s)
            const expiresIn = response.data.expires_in || 600;
            this.tokenExpiresAt = Date.now() + ((expiresIn - 60) * 1000);

            console.log('✅ Autenticação C6 Bank bem-sucedida');
            console.log('   Token expira em:', expiresIn, 'segundos');
            console.log('   Token (primeiros 50 chars):', this.accessToken.substring(0, 50) + '...');

            return this.accessToken;

        } catch (error) {
            console.error('❌ Erro ao autenticar no C6 Bank:', error.message);

            if (error.response) {
                console.error('   Status:', error.response.status);
                console.error('   Dados:', JSON.stringify(error.response.data, null, 2));
            }

            // Verificar se é horário de funcionamento do sandbox
            const now = new Date();
            const hour = now.getHours();
            const day = now.getDay(); // 0=domingo, 6=sábado

            if (this.environment === 'sandbox' && (day === 0 || day === 6 || hour < 7 || hour >= 23)) {
                throw new Error('Sandbox C6 Bank disponível apenas seg-sex, 07h-23h');
            }

            throw error;
        }
    }

    /**
     * Obtém um token válido (renova se expirado)
     * @returns {Promise<string>} Token de acesso válido
     */
    async getValidToken() {
        // Se não temos token ou está expirado, autentica novamente
        if (!this.accessToken || !this.tokenExpiresAt || Date.now() >= this.tokenExpiresAt) {
            console.log('🔄 Token expirado ou inexistente, renovando...');
            await this.authenticate();
        }

        return this.accessToken;
    }

    /**
     * Invalida o token atual (força renovação no próximo uso)
     */
    invalidateToken() {
        this.accessToken = null;
        this.tokenExpiresAt = null;
        console.log('🔒 Token invalidado');
    }
}

// Singleton para compartilhar estado do token entre requisições
const authInstance = new C6BankAuth();

module.exports = authInstance;
