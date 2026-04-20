-- Read-only pgbench script for reader-hostgroup measurements.
-- Single SELECT per transaction, no BEGIN/END. ProxySQL routes this to the
-- reader hostgroup (hg 20 in the lab topology) per default routing rules.
\set aid random(1, 100000 * :scale)
SELECT abalance FROM pgbench_accounts WHERE aid = :aid;
