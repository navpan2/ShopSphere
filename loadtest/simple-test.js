import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '30s', target: 20 },  // Ramp up to 20 users
    { duration: '1m', target: 20 },   // Stay at 20 users
    { duration: '30s', target: 0 },   // Ramp down
  ],
};

export default function() {
  // Test homepage
  let response = http.get('http://localhost:3000');
  check(response, {
    'homepage status is 200': (r) => r.status === 200,
  });

  // Test API health
  response = http.get('http://localhost:8001/health');
  check(response, {
    'API health status is 200': (r) => r.status === 200,
    'API is healthy': (r) => r.json().status === 'healthy',
  });

  // Test products API
  response = http.get('http://localhost:8001/products');
  check(response, {
    'products API status is 200': (r) => r.status === 200,
  });

  sleep(1);
}
