# Recommended SSL Configuration for your system
TLS_VERSION = "TLS 1.2"
SSL_CERT_PATH = "certs/server.crt"
SSL_KEY_PATH = "certs/server.key"

# Python SSL Context Settings:
import ssl

# Server Context
server_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
server_context.load_cert_chain('certs/server.crt', 'certs/server.key')

# Client Context  
client_context = ssl.create_default_context()
client_context.check_hostname = False
client_context.verify_mode = ssl.CERT_NONE

# Version and Cipher Configuration
# TLS 1.2 Configuration