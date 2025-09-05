<?php
// Database configuration (replace with AWS RDS endpoint & credentials)
$host     = "your-rds-endpoint.amazonaws.com";
$username = "admin";
$password = "your_db_password";
$database = "capstone_db";

// Create connection
$conn = new mysqli($host, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
    die("❌ Connection failed: " . $conn->connect_error);
}

echo "<h1>✅ Welcome to AWS Capstone PHP Web App</h1>";
echo "<p>Connected successfully to MySQL RDS at <b>$host</b></p>";

// Example query (create a test table if not exists)
$conn->query("CREATE TABLE IF NOT EXISTS visitors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    visit_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

// Insert visitor record
$conn->query("INSERT INTO visitors () VALUES ()");

// Count visitors
$result = $conn->query("SELECT COUNT(*) as total FROM visitors");
$row = $result->fetch_assoc();
echo "<p>Total Visitors: <b>" . $row['total'] . "</b></p>";

$conn->close();
?>