/**
 * pix.js - Gerador de Payload EMV BRCode / Copia e Cola para PIX (BCB Spec)
 * =========================================================================
 * Gera a string EMV oficial para pagamentos PIX com algoritmo CRC16-CCITT.
 */

class PixPayloadGenerator {
    constructor({ pixKey, merchantName, merchantCity, transactionAmount, txid = '***' }) {
        this.pixKey = this.formatPixKey(pixKey);
        this.merchantName = this.normalizeText(merchantName, 25);
        this.merchantCity = this.normalizeText(merchantCity, 15);
        this.transactionAmount = transactionAmount ? parseFloat(transactionAmount).toFixed(2) : null;
        this.txid = txid || '***';
    }

    formatPixKey(key) {
        if (!key) return '';
        const clean = key.trim();
        if (clean.includes('@') || clean.includes('-') || clean.startsWith('+')) return clean;
        const nums = clean.replace(/\D/g, '');
        if (nums.length === 11) return `+55${nums}`;
        if (nums.length === 13 && nums.startsWith('55')) return `+${nums}`;
        return clean;
    }

    normalizeText(text, maxLength) {
        if (!text) return 'N/A';
        return text
            .normalize('NFD')
            .replace(/[\u0300-\u036f]/g, '') // Remove acentos
            .replace(/[^a-zA-Z0-9 ]/g, '') // Apenas alfanuméricos
            .substring(0, maxLength)
            .toUpperCase();
    }

    formatEMV(id, value) {
        const len = value.length.toString().padStart(2, '0');
        return `${id}${len}${value}`;
    }

    getMerchantAccountInformation() {
        const gui = this.formatEMV('00', 'br.gov.bcb.pix');
        const key = this.formatEMV('01', this.pixKey);
        return this.formatEMV('26', gui + key);
    }

    getAdditionalDataFieldTemplate() {
        const txidEMV = this.formatEMV('05', this.txid);
        return this.formatEMV('62', txidEMV);
    }

    calculateCRC16(payload) {
        let crc = 0xFFFF;
        const polynomial = 0x1021;

        for (let i = 0; i < payload.length; i++) {
            crc ^= (payload.charCodeAt(i) << 8);
            for (let j = 0; j < 8; j++) {
                if ((crc & 0x8000) !== 0) {
                    crc = ((crc << 1) ^ polynomial) & 0xFFFF;
                } else {
                    crc = (crc << 1) & 0xFFFF;
                }
            }
        }
        return crc.toString(16).toUpperCase().padStart(4, '0');
    }

    generatePayload() {
        let payload = '';

        // 00 - Payload Format Indicator
        payload += this.formatEMV('00', '01');

        // 26 - Merchant Account Information (PIX)
        payload += this.getMerchantAccountInformation();

        // 52 - Merchant Category Code
        payload += this.formatEMV('52', '0000');

        // 53 - Transaction Currency (986 = BRL)
        payload += this.formatEMV('53', '986');

        // 54 - Transaction Amount (se informado)
        if (this.transactionAmount) {
            payload += this.formatEMV('54', this.transactionAmount);
        }

        // 58 - Country Code
        payload += this.formatEMV('58', 'BR');

        // 59 - Merchant Name
        payload += this.formatEMV('59', this.merchantName || 'ADMINISTRADOR');

        // 60 - Merchant City
        payload += this.formatEMV('60', this.merchantCity || 'SAO PAULO');

        // 62 - Additional Data Field (TXID)
        payload += this.getAdditionalDataFieldTemplate();

        // 63 - CRC16 (4 caracteres)
        payload += '6304';
        const crc = this.calculateCRC16(payload);

        return payload + crc;
    }
}

// Suporte para uso via Node CLI ou require
if (typeof module !== 'undefined' && module.exports) {
    module.exports = PixPayloadGenerator;
}

// Se executado via terminal CLI (ex: node pix.js 5511945457934 "ADMINISTRADOR" "SAO PAULO" 49.90)
if (typeof require !== 'undefined' && require.main === module) {
    const args = process.argv.slice(2);
    const pixKey = args[0] || '5511945457934';
    const name = args[1] || 'ADMINISTRADOR GERAL';
    const city = args[2] || 'SAO PAULO';
    const amount = args[3] || '49.90';

    const pix = new PixPayloadGenerator({
        pixKey: pixKey,
        merchantName: name,
        merchantCity: city,
        transactionAmount: amount
    });

    console.log('--- PAYLOAD EMV / COPIA E COLA PIX ---');
    console.log(pix.generatePayload());
}
