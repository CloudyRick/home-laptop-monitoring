# Monitoring Stack for Ubuntu Server

This monitoring stack provides comprehensive monitoring for your Ubuntu server, Docker applications, and PostgreSQL database with private access capabilities.

## 🏗️ Architecture

- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization dashboards
- **ELK Stack**: Log aggregation and analysis
  - **Elasticsearch**: Log storage
  - **Logstash**: Log processing
  - **Kibana**: Log visualization
- **cAdvisor**: Docker container metrics
- **Node Exporter**: System metrics
- **PostgreSQL Exporter**: Database metrics
- **Nginx**: Reverse proxy with authentication
- **Filebeat**: Log shipping

## 🚀 Quick Start

### Prerequisites

1. Ubuntu server with Docker and Docker Compose installed
2. PostgreSQL database running (can be in Docker or on host)
3. Domain names for private access (optional)

### Installation

1. **Clone or copy this monitoring directory to your server**

2. **Update PostgreSQL connection string** in `docker-compose.yml`:
   ```yaml
   environment:
     - DATA_SOURCE_NAME=postgresql://username:password@host.docker.internal:5432/database?sslmode=disable
   ```

3. **Run the deployment script**:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

4. **Access the monitoring dashboards**:
   - Grafana: `http://your-server-ip:3000` (admin/admin123)
   - Kibana: `http://your-server-ip:5601`
   - Prometheus: `http://your-server-ip:9090`
   - cAdvisor: `http://your-server-ip:8080`

## 🔒 Private Access Setup

### Option 1: Basic Authentication (HTTP)

The Nginx configuration includes basic authentication. Default credentials:
- Username: `admin`
- Password: `password`

**Change these credentials**:
```bash
# Generate new password hash
htpasswd -c /etc/nginx/.htpasswd newusername
```

### Option 2: VPN Access

1. **Set up OpenVPN or WireGuard** on your server
2. **Configure firewall rules** to restrict access to monitoring ports
3. **Update Nginx configuration** to bind to VPN interface only

### Option 3: SSL/TLS with Domain Names

1. **Obtain SSL certificates** (Let's Encrypt recommended)
2. **Update domain names** in `nginx/nginx.conf`
3. **Place certificates** in `nginx/ssl/`
4. **Uncomment SSL configuration** in `nginx/nginx.conf`

## 📊 Monitoring Configuration

### Application Logs

Configure your application to send logs to Logstash:

**Option 1: Direct TCP/UDP**
```bash
# Send logs to Logstash
echo '{"level":"info","message":"Application started"}' | nc your-server-ip 5000
```

**Option 2: File-based logging**
```bash
# Your app writes logs to /var/log/your-app/
# Filebeat will automatically collect them
```

**Option 3: Docker logging driver**
```yaml
# In your app's docker-compose.yml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

### PostgreSQL Monitoring

The PostgreSQL exporter requires specific permissions. Create a monitoring user:

```sql
-- Connect to PostgreSQL as superuser
CREATE USER monitoring WITH PASSWORD 'monitoring_password';
GRANT pg_monitor TO monitoring;
GRANT SELECT ON pg_stat_database TO monitoring;
```

Update the connection string in `docker-compose.yml`:
```yaml
- DATA_SOURCE_NAME=postgresql://monitoring:monitoring_password@host.docker.internal:5432/your_database?sslmode=disable
```

### Custom Metrics

Add custom metrics to your application:

**Python Example**:
```python
from prometheus_client import Counter, Histogram, start_http_server

# Define metrics
REQUEST_COUNT = Counter('app_requests_total', 'Total requests')
REQUEST_DURATION = Histogram('app_request_duration_seconds', 'Request duration')

# In your application
@REQUEST_DURATION.time()
def handle_request():
    REQUEST_COUNT.inc()
    # Your application logic
```

## 🔧 Configuration Files

### Prometheus (`prometheus/prometheus.yml`)
- Scrape intervals and targets
- Alert rules for system, Docker, and PostgreSQL

### Grafana (`grafana/provisioning/`)
- Data source configuration
- Dashboard provisioning

### Logstash (`logstash/pipeline/logstash.conf`)
- Log parsing and filtering
- Output to Elasticsearch

### Filebeat (`filebeat/filebeat.yml`)
- Log collection from various sources
- Docker container logs
- System logs
- Application logs

### Nginx (`nginx/nginx.conf`)
- Reverse proxy configuration
- Basic authentication
- SSL/TLS support

## 📈 Dashboards

### Grafana Dashboards
- **System Overview**: CPU, Memory, Disk usage
- **Docker Containers**: Container metrics and logs
- **PostgreSQL**: Database performance and connections
- **Application Metrics**: Custom application metrics

### Kibana Dashboards
- **Log Analysis**: Search and filter logs
- **Error Tracking**: Application errors and exceptions
- **Performance Monitoring**: Response times and throughput

## 🚨 Alerting

Prometheus alert rules are configured in `prometheus/rules/alerts.yml`:

- **System Alerts**: High CPU, Memory, Disk usage
- **Docker Alerts**: Container down, high resource usage
- **PostgreSQL Alerts**: Database down, high connections, slow queries

### Alert Notifications

Configure alert notifications in Prometheus:

```yaml
# Add to prometheus.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093
```

## 🔧 Maintenance

### Log Rotation
```bash
# Configure logrotate for application logs
sudo nano /etc/logrotate.d/your-app
```

### Backup
```bash
# Backup Grafana dashboards
docker exec grafana grafana-cli admin export-dashboard > backup.json

# Backup Prometheus data
docker exec prometheus promtool tsdb create-blocks-from openmetrics prometheus_data/
```

### Updates
```bash
# Update monitoring stack
docker-compose pull
docker-compose up -d
```

## 🐛 Troubleshooting

### Common Issues

1. **Services not starting**: Check Docker logs
   ```bash
   docker-compose logs [service-name]
   ```

2. **PostgreSQL connection failed**: Verify connection string and permissions

3. **Logs not appearing**: Check Filebeat configuration and log paths

4. **High memory usage**: Adjust Elasticsearch heap size in `docker-compose.yml`

### Performance Tuning

1. **Elasticsearch**: Adjust heap size based on available memory
2. **Logstash**: Increase pipeline workers for high log volume
3. **Prometheus**: Configure retention policies for metrics

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [ELK Stack Documentation](https://www.elastic.co/guide/)
- [Docker Monitoring Best Practices](https://docs.docker.com/config/containers/logging/)

## 🔐 Security Considerations

1. **Change default passwords** immediately
2. **Use SSL/TLS** for production environments
3. **Restrict network access** using firewall rules
4. **Regular security updates** for all components
5. **Monitor access logs** for suspicious activity

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review Docker logs: `docker-compose logs`
3. Verify configuration files
4. Check service status: `docker-compose ps`
