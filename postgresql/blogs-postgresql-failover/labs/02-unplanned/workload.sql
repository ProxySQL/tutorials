\set id random(1, 100000)
\set balance random(-5000, 5000)
BEGIN;
UPDATE pgbench_accounts SET abalance = abalance + :balance WHERE aid = :id;
END;
