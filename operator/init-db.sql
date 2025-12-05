-- Bastion Operator Database Schema

-- Price history table
CREATE TABLE IF NOT EXISTS price_history (
    id SERIAL PRIMARY KEY,
    asset VARCHAR(50) NOT NULL,
    price VARCHAR(78) NOT NULL,
    decimals INT NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    round_id VARCHAR(78) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(asset, round_id)
);

CREATE INDEX idx_price_history_asset_timestamp ON price_history(asset, timestamp DESC);

-- Depeg events table
CREATE TABLE IF NOT EXISTS depeg_events (
    id SERIAL PRIMARY KEY,
    asset VARCHAR(50) NOT NULL,
    depeg_bps VARCHAR(78) NOT NULL,
    steth_price VARCHAR(78) NOT NULL,
    eth_price VARCHAR(78) NOT NULL,
    detected_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_depeg_events_detected ON depeg_events(detected_at DESC);

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    task_index INT NOT NULL UNIQUE,
    task_type INT NOT NULL,
    task_data BYTEA,
    created_block INT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW(),
    responded_at TIMESTAMP,
    completed_at TIMESTAMP
);

CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_created ON tasks(created_at DESC);

-- Task responses table
CREATE TABLE IF NOT EXISTS task_responses (
    id SERIAL PRIMARY KEY,
    task_index INT NOT NULL REFERENCES tasks(task_index),
    operator_address VARCHAR(42) NOT NULL,
    response_data BYTEA NOT NULL,
    signature BYTEA NOT NULL,
    submitted_at TIMESTAMP DEFAULT NOW(),
    tx_hash VARCHAR(66),
    confirmed BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_responses_task ON task_responses(task_index);
CREATE INDEX idx_responses_operator ON task_responses(operator_address);

-- Operator state table
CREATE TABLE IF NOT EXISTS operator_state (
    id SERIAL PRIMARY KEY,
    operator_address VARCHAR(42) NOT NULL UNIQUE,
    registration_status VARCHAR(20) DEFAULT 'unregistered',
    stake_amount VARCHAR(78),
    bls_pub_key VARCHAR(200),
    registered_at TIMESTAMP,
    last_heartbeat TIMESTAMP,
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Metrics table
CREATE TABLE IF NOT EXISTS operator_metrics (
    id SERIAL PRIMARY KEY,
    metric_name VARCHAR(100) NOT NULL,
    metric_value DECIMAL,
    labels JSONB,
    recorded_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_metrics_name_time ON operator_metrics(metric_name, recorded_at DESC);

-- Insert initial operator state
INSERT INTO operator_state (operator_address)
VALUES ('0x0000000000000000000000000000000000000000')
ON CONFLICT (operator_address) DO NOTHING;
