const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(cors()); // Allows frontend to request data from this API

// Database connection config (Uses environment variables)
const dbConfig = {
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'secret',
    database: process.env.DB_NAME || 'testdb'
};

// Simple endpoint that tests database connection
app.get('/api/status', (req, res) => {
    const connection = mysql.createConnection(dbConfig);
    
    connection.connect((err) => {
        if (err) {
            console.error('Database connection failed:', err.stack);
            return res.status(500).json({ message: "Database Connection Failed! ❌" });
        }
        
        // Simple query to verify DB works
        connection.query('SELECT "Database Connected Successfully!  " AS msg', (queryErr, results) => {
            connection.end();
            if (queryErr) {
                return res.status(500).json({ message: "Query Failed! ❌" });
            }
            res.json({ message: results[0].msg });
        });
    });
});

app.listen(5000, () => {
    console.log('Backend server running on port 5000');
});
