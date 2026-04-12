================================================================================
DORKCOIN WALLET - BROADCAST ENDPOINT SETUP
================================================================================

PURPOSE:
--------
This package enables transaction broadcasting for the Dorkcoin mobile wallet.
The mobile wallet signs transactions offline and needs this endpoint to
broadcast them to the Dorkcoin network.

FILES INCLUDED:
---------------
1. broadcast.js       - Standalone broadcast endpoint module
2. app.js.modified    - Example showing where to add the code
3. README.txt         - This file

WHY THIS SOLUTION:
------------------
- Non-intrusive: Does not modify existing explorer code
- Standalone: Easy to remove if not needed
- Safe: Won't break existing read-only endpoints
- Simple: Only 2 lines of code to add

REQUIREMENTS:
-------------
- Dorkcoin node with RPC enabled
- Wallet must have sendrawtransaction capability
- Node must be synced with the network

================================================================================
INSTALLATION INSTRUCTIONS
================================================================================

STEP 1: Copy broadcast.js
-------------------------
Copy the file "broadcast.js" to your explorer root directory
(same folder as app.js)

STEP 2: Modify app.js
---------------------
Open your "app.js" file and find this line:

    app.use('/api', nodeapi());

BEFORE that line, add these 2 lines:

    const broadcast = require('./broadcast');
    broadcast.setup(app, client);

The result should look like this:

    
    // Add broadcast endpoint for mobile wallet
    const broadcast = require('./broadcast');
    broadcast.setup(app, client);
    
    // Existing API routes (keep this)
    app.use('/api', nodeapi());
    
    // ... rest of code ...

IMPORTANT: The broadcast.setup() MUST be called BEFORE app.use('/api', nodeapi())

STEP 3: Restart Explorer
------------------------
Stop the explorer:
    npm stop

Start the explorer:
    npm start

Or if using PM2:
    pm2 restart explorer

STEP 4: Test the Endpoint
-------------------------
Open browser and test:
    https://your-explorer.com/api/broadcast?hex=010000...

Expected error (if hex is invalid):
    {"error":"Invalid hex format - must be hexadecimal string"}

Expected success:
    {"success":true,"txid":"abc123...","message":"Transaction broadcast successfully"}

================================================================================
ROLLBACK INSTRUCTIONS (If Something Goes Wrong)
================================================================================

If you need to remove this feature:

1. Open app.js
2. Remove these 2 lines:
       const broadcast = require('./broadcast');
       broadcast.setup(app, client);
3. Delete the file broadcast.js
4. Restart the explorer

================================================================================
TROUBLESHOOTING
================================================================================

Problem: "Cannot find module './broadcast'"
Solution: Make sure broadcast.js is in the same folder as app.js

Problem: "client is not defined"
Solution: The 'client' variable must be the RPC client instance. Check your
          app.js to see what variable name is used for the RPC client.

Problem: "Method not found"
Solution: Your Dorkcoin node may not support sendrawtransaction. Make sure
          the wallet is compiled with transaction support.

Problem: "Insufficient funds" or similar
Solution: This is a wallet issue, not an endpoint issue. The transaction
          hex may be invalid or the wallet doesn't have funds.

================================================================================
SUPPORT
================================================================================

For issues with this setup, contact the Dorkcoin wallet development team.

For explorer issues, check the eIquidus documentation:
https://github.com/team-exor/eiquidus

================================================================================
END OF FILE
================================================================================
