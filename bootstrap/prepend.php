<?php
// Start output buffering early to prevent "headers already sent"
if (!ob_get_level()) {
    ob_start();
}

// DO NOT start session here
// Let CodeIgniter handle session_start()
