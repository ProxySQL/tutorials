from probes import parse_connection_pool_tsv, parse_show_pgsql_servers_tsv


def test_parse_connection_pool_tsv_returns_list_of_rows() -> None:
    tsv = (
        "10\t127.0.0.1\t5433\tONLINE\t1\t3\t0\t0\t0\t12345\t6789\t0\t0\n"
        "20\t127.0.0.1\t5434\tONLINE\t0\t2\t1\t0\t0\t23456\t1234\t0\t0\n"
    )
    rows = parse_connection_pool_tsv(tsv)
    assert len(rows) == 2
    assert rows[0]["hostgroup"] == 10
    assert rows[0]["status"] == "ONLINE"
    assert rows[1]["host"] == "127.0.0.1"
    assert rows[1]["port"] == 5434


def test_parse_show_pgsql_servers_returns_host_status_pairs() -> None:
    tsv = (
        "10\t127.0.0.1\t5433\tONLINE\t1000\t0\t1000\t1\t1000\t0\t\n"
        "20\t127.0.0.1\t5434\tSHUNNED\t1000\t0\t1000\t1\t1000\t0\t\n"
    )
    servers = parse_show_pgsql_servers_tsv(tsv)
    assert servers[("127.0.0.1", "5433", "10")] == "ONLINE"
    assert servers[("127.0.0.1", "5434", "20")] == "SHUNNED"


def test_parse_handles_empty_input() -> None:
    assert parse_connection_pool_tsv("") == []
    assert parse_show_pgsql_servers_tsv("") == {}


def test_status_to_code_maps_known_states() -> None:
    from probes import status_to_code

    assert status_to_code("ONLINE") == 0
    assert status_to_code("SHUNNED") == 1
    assert status_to_code("OFFLINE_SOFT") == 2
    assert status_to_code("OFFLINE_HARD") == 3
    assert status_to_code("UNKNOWN_STATE") == -1


def test_summarize_backend_state_picks_primary_hostgroup() -> None:
    from probes import summarize_backend_state

    servers = {
        ("127.0.0.1", "5433", "10"): "ONLINE",   # writer hg 10
        ("127.0.0.1", "5434", "20"): "ONLINE",   # reader hg 20
        ("127.0.0.1", "5435", "20"): "SHUNNED",
    }
    state = summarize_backend_state(servers, writer_hg="10")
    assert state["writer_state_code"] == 0  # ONLINE
    # worst reader wins for reader_state_code
    assert state["reader_state_code"] == 1  # SHUNNED


def test_parse_connection_pool_tsv_returns_per_backend_counters() -> None:
    from probes import parse_connection_pool_tsv

    tsv = "\n".join([
        "10\t127.0.0.1\t5433\tONLINE\t5\t3\t100\t0\t8\t0\t0\t0\t0",
        "20\t127.0.0.1\t5434\tONLINE\t2\t6\t50\t1\t6\t0\t0\t0\t0",
        "20\t127.0.0.1\t5435\tONLINE\t1\t7\t30\t0\t7\t0\t0\t0\t0",
    ])
    rows = parse_connection_pool_tsv(tsv)

    assert rows[0] == {
        "hostgroup": 10, "host": "127.0.0.1", "port": 5433,
        "status": "ONLINE", "conn_used": 5, "conn_free": 3,
        "conn_ok": 100, "conn_err": 0,
    }
    assert len(rows) == 3
    assert rows[2]["host"] == "127.0.0.1" and rows[2]["port"] == 5435


def test_parse_connection_pool_tsv_handles_empty_input() -> None:
    from probes import parse_connection_pool_tsv

    assert parse_connection_pool_tsv("") == []


def test_summarize_writer_conn_used_sums_writer_hg_only() -> None:
    from probes import summarize_writer_conn_used

    rows = [
        {"hostgroup": 10, "host": "127.0.0.1", "port": 5433,
         "status": "ONLINE", "conn_used": 5, "conn_free": 3,
         "conn_ok": 100, "conn_err": 0},
        {"hostgroup": 20, "host": "127.0.0.1", "port": 5434,
         "status": "ONLINE", "conn_used": 2, "conn_free": 6,
         "conn_ok": 50, "conn_err": 1},
        {"hostgroup": 20, "host": "127.0.0.1", "port": 5435,
         "status": "ONLINE", "conn_used": 1, "conn_free": 7,
         "conn_ok": 30, "conn_err": 0},
    ]
    assert summarize_writer_conn_used(rows, writer_hg=10) == 5


def test_summarize_writer_conn_used_returns_zero_when_writer_empty() -> None:
    from probes import summarize_writer_conn_used

    rows = [
        {"hostgroup": 20, "host": "127.0.0.1", "port": 5434,
         "status": "ONLINE", "conn_used": 2, "conn_free": 6,
         "conn_ok": 50, "conn_err": 1},
    ]
    assert summarize_writer_conn_used(rows, writer_hg=10) == 0
