const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json()); // Allows backend to parse JSON request bodies

// Database connection config
const dbConfig = {
    host: process.env.DB_HOST || 'localhost',
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || 'secret',
    database: process.env.DB_NAME || 'testdb'
};

// Automatically initialize the database table on startup
const initDB = () => {
    const connection = mysql.createConnection(dbConfig);
    connection.connect((err) => {
        if (err) {
            console.error('Initial DB connection failed, retrying in 5s...', err.message);
            setTimeout(initDB, 5000);
            return;
        }
        const createTableSql = `
            CREATE TABLE IF NOT EXISTS messages (
                id INT AUTO_INCREMENT PRIMARY KEY,
                text VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `;
        connection.query(createTableSql, (tableErr) => {
            connection.end();
            if (tableErr) console.error('Failed to initialize table:', tableErr.message);
            else console.log('Database table "messages" verified.');
        });
    });
};
initDB();

// 1. Connection Status Check Endpoint
app.get('/api/status', (req, res) => {
    const connection = mysql.createConnection(dbConfig);
    connection.connect((err) => {
        if (err) return res.status(500).json({ message: "Database Connection Failed! ❌" });
        connection.query('SELECT "Database Connected Successfully!  " AS msg', (queryErr, results) => {
            connection.end();
            if (queryErr) return res.status(500).json({ message: "Query Failed! ❌" });
            res.json({ message: results[0].msg });
        });
    });
});

// 2. Write Message Endpoint (Create)
app.post('/api/message', (req, res) => {
    const { text } = req.body;
    if (!text) return res.status(400).json({ error: "Text is required" });

    const connection = mysql.createConnection(dbConfig);
    connection.query('INSERT INTO messages (text) VALUES (?)', [text], (err) => {
        connection.end();
        if (err) return res.status(500).json({ error: err.message });
        res.json({ success: true, message: "Saved to DB!" });
    });
});

// 3. Retrieve Messages Endpoint (Read)
app.get('/api/messages', (req, res) => {
    const connection = mysql.createConnection(dbConfig);
    connection.query('SELECT text, DATE_FORMAT(created_at, "%Y-%m-%d %H:%i:%s") as date FROM messages ORDER BY id DESC', (err, results) => {
        connection.end();
        if (err) return res.status(500).json({ error: err.message });
        res.json(results);
    });
});

app.listen(5000, () => {
    console.log('Backend server running on port 5000');
});