const db = require('../database/db');

/**
 * Módulo para processar webhooks do C6 Bank
 * Processa notificações de PIX, Boleto e Checkout
 */
class C6BankWebhook {

    /**
     * Processa webhook de PIX
     * @param {object} payload - Dados do webhook
     * @returns {Promise<boolean>} True se processado com sucesso
     */
    async processPix(payload) {
        try {
            console.log('🔔 Processando webhook PIX...');
            console.log('   Payload:', JSON.stringify(payload, null, 2));

            // Registrar webhook no banco
            await db.run(`
                INSERT INTO webhook_logs (txid, event_type, payload, processed)
                VALUES (?, ?, ?, 0)
            `, [payload.txid || 'unknown', 'PIX', JSON.stringify(payload)]);

            // Verificar se é notificação de pagamento
            if (payload.pix && payload.pix.length > 0) {
                const txid = payload.txid;
                const e2eId = payload.pix[0].endToEndId;

                console.log('💰 Pagamento PIX recebido!');
                console.log('   TXID:', txid);
                console.log('   E2E ID:', e2eId);

                // Buscar pagamento no banco
                const payment = await db.get(
                    'SELECT * FROM payments WHERE c6bank_txid = ?',
                    [txid]
                );

                if (!payment) {
                    console.warn('⚠️ Pagamento não encontrado para TXID:', txid);
                    return false;
                }

                if (payment.status === 'confirmed') {
                    console.log('ℹ️ Pagamento já confirmado anteriormente');
                    return true;
                }

                // Atualizar pagamento
                await db.run(`
                    UPDATE payments
                    SET status = 'confirmed',
                        c6bank_status = 'CONCLUIDA',
                        c6bank_e2e_id = ?,
                        webhook_received_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                `, [e2eId, payment.id]);

                // Atualizar pedido
                await db.run(`
                    UPDATE orders
                    SET status = 'paid', updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                `, [payment.order_id]);

                // Liberar cursos
                const orderItems = await db.all(
                    'SELECT * FROM order_items WHERE order_id = ?',
                    [payment.order_id]
                );

                const order = await db.get(
                    'SELECT user_id FROM orders WHERE id = ?',
                    [payment.order_id]
                );

                for (const item of orderItems) {
                    await db.run(`
                        INSERT OR IGNORE INTO user_courses (user_id, course_id, order_id)
                        VALUES (?, ?, ?)
                    `, [order.user_id, item.course_id, payment.order_id]);
                }

                console.log('✅ Pagamento confirmado e cursos liberados!');

                // Marcar webhook como processado
                await db.run(`
                    UPDATE webhook_logs
                    SET processed = 1
                    WHERE txid = ? AND event_type = 'PIX'
                    ORDER BY created_at DESC
                    LIMIT 1
                `, [txid]);

                return true;
            }

            return false;

        } catch (error) {
            console.error('❌ Erro ao processar webhook PIX:', error.message);

            // Registrar erro no log
            if (payload.txid) {
                await db.run(`
                    UPDATE webhook_logs
                    SET error_message = ?
                    WHERE txid = ? AND event_type = 'PIX'
                    ORDER BY created_at DESC
                    LIMIT 1
                `, [error.message, payload.txid]);
            }

            throw error;
        }
    }

    /**
     * Processa webhook de Boleto
     * @param {object} payload - Dados do webhook
     * @returns {Promise<boolean>} True se processado com sucesso
     */
    async processBoleto(payload) {
        try {
            console.log('🔔 Processando webhook Boleto...');
            console.log('   Payload:', JSON.stringify(payload, null, 2));

            const boletoId = payload.id || payload.bank_slip_id;

            // Registrar webhook
            await db.run(`
                INSERT INTO webhook_logs (txid, event_type, payload, processed)
                VALUES (?, ?, ?, 0)
            `, [boletoId, 'BOLETO', JSON.stringify(payload)]);

            // Verificar se boleto foi pago
            if (payload.status === 'PAID' || payload.status === 'SETTLED') {
                console.log('💰 Boleto pago!');
                console.log('   ID:', boletoId);

                // Buscar pagamento pelo ID do boleto
                const payment = await db.get(
                    'SELECT * FROM payments WHERE boleto_id = ?',
                    [boletoId]
                );

                if (!payment) {
                    console.warn('⚠️ Pagamento não encontrado para boleto:', boletoId);
                    return false;
                }

                if (payment.status === 'confirmed') {
                    console.log('ℹ️ Pagamento já confirmado');
                    return true;
                }

                // Atualizar pagamento e liberar cursos (mesmo processo do PIX)
                await db.run(`
                    UPDATE payments
                    SET status = 'confirmed',
                        webhook_received_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                `, [payment.id]);

                await db.run(`
                    UPDATE orders
                    SET status = 'paid', updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                `, [payment.order_id]);

                // Liberar cursos
                const orderItems = await db.all(
                    'SELECT * FROM order_items WHERE order_id = ?',
                    [payment.order_id]
                );

                const order = await db.get(
                    'SELECT user_id FROM orders WHERE id = ?',
                    [payment.order_id]
                );

                for (const item of orderItems) {
                    await db.run(`
                        INSERT OR IGNORE INTO user_courses (user_id, course_id, order_id)
                        VALUES (?, ?, ?)
                    `, [order.user_id, item.course_id, payment.order_id]);
                }

                console.log('✅ Boleto confirmado e cursos liberados!');

                await db.run(`
                    UPDATE webhook_logs
                    SET processed = 1
                    WHERE txid = ? AND event_type = 'BOLETO'
                    ORDER BY created_at DESC
                    LIMIT 1
                `, [boletoId]);

                return true;
            }

            return false;

        } catch (error) {
            console.error('❌ Erro ao processar webhook Boleto:', error.message);
            throw error;
        }
    }

    /**
     * Processa webhook de Checkout (Cartão)
     * @param {object} payload - Dados do webhook
     * @returns {Promise<boolean>} True se processado com sucesso
     */
    async processCheckout(payload) {
        try {
            console.log('🔔 Processando webhook Checkout...');
            console.log('   Payload:', JSON.stringify(payload, null, 2));

            const checkoutId = payload.id || payload.checkout_id;

            // Registrar webhook
            await db.run(`
                INSERT INTO webhook_logs (txid, event_type, payload, processed)
                VALUES (?, ?, ?, 0)
            `, [checkoutId, 'CHECKOUT', JSON.stringify(payload)]);

            // Verificar se checkout foi aprovado
            if (payload.status === 'PAID' || payload.status === 'APPROVED') {
                console.log('💰 Checkout aprovado!');
                console.log('   ID:', checkoutId);

                // Buscar pagamento pelo ID do checkout
                const payment = await db.get(
                    'SELECT * FROM payments WHERE card_transaction_id = ?',
                    [checkoutId]
                );

                if (!payment) {
                    console.warn('⚠️ Pagamento não encontrado para checkout:', checkoutId);
                    return false;
                }

                if (payment.status === 'confirmed') {
                    console.log('ℹ️ Pagamento já confirmado');
                    return true;
                }

                // Atualizar pagamento e liberar cursos
                await db.run(`
                    UPDATE payments
                    SET status = 'confirmed',
                        webhook_received_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                `, [payment.id]);

                await db.run(`
                    UPDATE orders
                    SET status = 'paid', updated_at = CURRENT_TIMESTAMP
                    WHERE id = ?
                `, [payment.order_id]);

                // Liberar cursos
                const orderItems = await db.all(
                    'SELECT * FROM order_items WHERE order_id = ?',
                    [payment.order_id]
                );

                const order = await db.get(
                    'SELECT user_id FROM orders WHERE id = ?',
                    [payment.order_id]
                );

                for (const item of orderItems) {
                    await db.run(`
                        INSERT OR IGNORE INTO user_courses (user_id, course_id, order_id)
                        VALUES (?, ?, ?)
                    `, [order.user_id, item.course_id, payment.order_id]);
                }

                console.log('✅ Checkout confirmado e cursos liberados!');

                await db.run(`
                    UPDATE webhook_logs
                    SET processed = 1
                    WHERE txid = ? AND event_type = 'CHECKOUT'
                    ORDER BY created_at DESC
                    LIMIT 1
                `, [checkoutId]);

                return true;
            }

            return false;

        } catch (error) {
            console.error('❌ Erro ao processar webhook Checkout:', error.message);
            throw error;
        }
    }
}

const webhookInstance = new C6BankWebhook();

module.exports = webhookInstance;
