<?php
// Deployment diagnostic. Remove after debugging.
echo "PHP OK\n";
echo "HTTPS=" . ($_SERVER['HTTPS'] ?? 'not set') . "\n";
echo "SERVER_PORT=" . ($_SERVER['SERVER_PORT'] ?? 'not set') . "\n";
echo "HTTP_X_FORWARDED_PROTO=" . ($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? 'not set') . "\n";
