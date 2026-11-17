import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://demo-app.demo.svc.cluster.local';

// Requests per second for each stage, held for 60 s with a 15 s pause in between
const RATES = [50, 100, 150, 200, 300, 400];
const STAGE_SECONDS = 60;
const PAUSE_SECONDS = 15;

const scenarios = {};
const thresholds = {};

RATES.forEach((rate, i) => {
  const stage = `${rate}rps`;

  scenarios[stage] = {
    executor: 'constant-arrival-rate', // fixed request rate, whatever the response time
    rate: rate,
    timeUnit: '1s',
    duration: `${STAGE_SECONDS}s`,
    preAllocatedVUs: 100,
    maxVUs: 2000,
    startTime: `${i * (STAGE_SECONDS + PAUSE_SECONDS)}s`,
    tags: { stage: stage },
  };

  // Per-stage thresholds: they also make k6 print each stage's metrics in the summary
  thresholds[`http_req_duration{stage:${stage}}`] = ['p(95)<500'];
  thresholds[`http_req_failed{stage:${stage}}`] = ['rate<0.01'];
  thresholds[`http_reqs{stage:${stage}}`] = ['count>=0'];
  thresholds[`dropped_iterations{stage:${stage}}`] = ['count>=0'];
});

export const options = { scenarios, thresholds };

export default function () {
  // 80% cheap requests, 20% requests that burn 20 ms of CPU
  const res = Math.random() < 0.8
    ? http.get(`${BASE_URL}/`)
    : http.get(`${BASE_URL}/work?ms=20`);

  check(res, { 'status is 200': (r) => r.status === 200 });
}
