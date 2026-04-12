/**
 * Standalone Broadcast Endpoint for Dorkcoin Wallet
 * 
 * This module provides a secure /api/broadcast endpoint for submitting
 * raw transactions to the Dorkcoin network without modifying existing
 * explorer code.
 * 
 * Author: Dorkcoin Wallet Team
 * Version: 1.0.0
 */

module.exports = {
  /**
   * Setup the broadcast endpoint
   * @param {Object} app - Express app instance
   * @param {Object} client - RPC client instance
   */
  setup: function(app, client) {
    // Broadcast endpoint - MUST be registered BEFORE nodeapi router
    app.get('/api/broadcast', function(req, res) {
      const hex = req.query.hex;
      
      // Validate hex parameter
      if (!hex) {
        return res.json({ 
          error: 'Missing hex parameter',
          example: '/api/broadcast?hex=010000...'
        });
      }

      // Validate hex format (must be valid hexadecimal)
      if (!/^[0-9a-fA-F]+$/.test(hex)) {
        return res.json({ error: 'Invalid hex format - must be hexadecimal string' });
      }

      // Call sendrawtransaction via RPC
      client.cmd('sendrawtransaction', [hex], function(err, txid) {
        if (err) {
          console.log('[Broadcast Error]', err);
          return res.json({ 
            error: err.message || 'Broadcast failed',
            code: err.code || 'UNKNOWN'
          });
        }
        
        // Return TXID on success
        res.json({ 
          success: true,
          txid: txid,
          message: 'Transaction broadcast successfully'
        });
      });
    });

    console.log('[Broadcast] Endpoint /api/broadcast registered successfully');
  }
};
