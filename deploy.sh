#!/bin/bash

# Monitoring Stack Deployment Script
# Run this script on your Ubuntu server

set -e

echo "🚀 Starting Monitoring Stack Deployment..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "Run: curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed. Please install Docker Compose first."
    echo "Run: sudo curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose && sudo chmod +x /usr/local/bin/docker-compose"
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
sudo mkdir -p /var/log/your-app
sudo chmod 755 /var/log/your-app

# Create basic auth file for nginx
echo "🔐 Setting up authentication..."
echo "admin:\$2y\$10\$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi" | sudo tee /etc/nginx/.htpasswd
echo "Default credentials: admin / password"
echo "⚠️  IMPORTANT: Change these credentials after deployment!"

# Update PostgreSQL connection string in docker-compose.yml
echo "🔧 Please update the PostgreSQL connection string in docker-compose.yml:"
echo "   DATA_SOURCE_NAME=postgresql://username:password@host.docker.internal:5432/database?sslmode=disable"

# Start the monitoring stack
echo "🐳 Starting monitoring services..."
docker-compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Check service status
echo "📊 Checking service status..."
docker-compose ps

echo "⏳ Waiting for Elasticsearch API to become ready..."
# Wait for Elasticsearch HTTP to be ready (up to ~2 minutes)
ATTEMPTS=60
SLEEP_SECS=2
for i in $(seq 1 $ATTEMPTS); do
  if curl -s http://localhost:9200 >/dev/null; then
    echo "✅ Elasticsearch is responding."
    break
  fi
  if [ "$i" -eq "$ATTEMPTS" ]; then
    echo "❌ Elasticsearch did not become ready in time."
    exit 1
  fi
  sleep $SLEEP_SECS
done

echo "🧹 Configuring ILM: delete logstash-* indices after 7 days..."
# Create or update ILM policy
curl -sS -X PUT "http://localhost:9200/_ilm/policy/logstash-delete-7d" \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{
  "policy": {
    "phases": {
      "delete": {
        "min_age": "7d",
        "actions": { "delete": {} }
      }
    }
  }
}
JSON

# Create or update index template to attach ILM policy to future indices
curl -sS -X PUT "http://localhost:9200/_index_template/logstash-template" \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{
  "index_patterns": ["logstash-*"],
  "template": {
    "settings": {
      "index.lifecycle.name": "logstash-delete-7d"
    }
  }
}
JSON

# Attach ILM policy to any existing logstash-* indices
curl -sS -X PUT "http://localhost:9200/logstash-*/_settings" \
  -H 'Content-Type: application/json' \
  -d @- <<'JSON'
{
  "index": {
    "lifecycle": { "name": "logstash-delete-7d" }
  }
}
JSON

echo "✅ ILM configured: logstash-* will be deleted after 7 days."

echo "✅ Monitoring stack deployed successfully!"
echo ""
echo "🌐 Access URLs:"
echo "   Grafana Dashboard: http://your-server-ip:3000 (admin/admin123)"
echo "   Kibana Logs: http://your-server-ip:5601"
echo "   Prometheus: http://your-server-ip:9090"
echo "   cAdvisor: http://your-server-ip:8080"
echo ""
cat <<'EOT'
🔎 To view top containers by log volume (doc counts), run either command:

curl -s 'http://localhost:9200/logstash-*/_search' -H 'Content-Type: application/json' -d '{
  "size": 0,
  "aggs": { "by_container": { "terms": { "field": "container.name.keyword", "size": 20 } } }
}'

# Or using the field added by Logstash's mutate (if mapped as keyword):
curl -s 'http://localhost:9200/logstash-*/_search' -H 'Content-Type: application/json' -d '{
  "size": 0,
  "aggs": { "by_container": { "terms": { "field": "container_name.keyword", "size": 20 } } }
}'
EOT

echo "🔒 For private access, configure your domain names in nginx/nginx.conf"
echo "   and set up SSL certificates in nginx/ssl/"
echo ""
echo "📝 Next steps:"
echo "   1. Update PostgreSQL connection string in docker-compose.yml"
echo "   2. Configure your application to send logs to Logstash"
echo "   3. Set up SSL certificates for HTTPS access"
echo "   4. Change default passwords"
echo "   5. Configure VPN access if needed"
