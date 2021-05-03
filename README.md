# EOSIO History Tools ![EOSIO Alpha](https://img.shields.io/badge/EOSIO-Alpha-blue.svg)

[![Software License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](./LICENSE)

The history tools repo has these components:

* Database fillers connect to the nodeos state-history plugin and populate databases
* wasm-ql servers answer incoming queries by running server WASMs, which have read-only access to the databases
* The wasm-ql library, when combined with the CDT library, provides utilities that server WASMs and client WASMs need
* A set of example server WASMs and client WASMs

| App               | Fills RocksDB | wasm-ql with RocksDB       | Fills PostgreSQL | wasm-ql with PostgreSQL |
| ----------------- | ------------- | -------------------------- | ---------------- | ---------------- |
| `fill-rocksdb`    | Yes           |                            |                  |                  |        
| `wasm-ql-rocksdb` |               | Yes                        |                  |                  |            
| `combo-rocksdb`   | Yes           | Yes                        |                  |                  |            
| `fill-pg`         |               |                            | Yes              |                  |        
| `wasm-ql-pg`      |               |                            |                  | Yes              |            
| `history-tools`   | Yes*          | Yes*                       | Yes*             | Yes*             |            

Note: by default, `history-tools` does nothing; use the `--plugin` option to select plugins.

See the [documentation site](https://eosio.github.io/history-tools/)

# Upcoming Release

The release contains only `fill-pq`, all the rest of the tools are deprecated. 

### SHiP protocol changes

SHiP protocol has been changed to allow a client to request the block_header only instead of the entire block. `fill-pq` has been update to
utilize this feature when the `nodeos` it connects to support it. 
### PostgreSQL table schema changes

This release completely rewrites the SHiP protocol to SQL conversion code so that the database tables
would directly align with the data structures defined in the SHiP protocol. This also changes for table schema used by previous releases.
Here are the basic rules for the conversion:

  - Nested SHiP `struct` types with more than one fields are mapped to SQL custom types.
  - Nested SHiP `vector` types are mapped to SQL arrays.
  - SHiP `variant` types are mapped to a SQL type or table containing the union fields of their constituent types.  

Consequently, instead having their own tables in previous releases, `action_trace`, `action_trace_ram_delta`, `action_trace_auth_sequence` and `action_trace_authorization` are arrays nested inside `transaction_trace` table or `action_trace` type. The SQL `UNNEST` operator can be used to flatten arrays into tables for query. 

The current list of tables created by  `fill-pg` are:
  - account
  - account_metadata
  - block_info  
  - code                      
  - contract_index_double
  - contract_index_long_double
  - contract_index128
  - contract_index256
  - contract_index64 
  - contract_row
  - contract_table
  - fill_status
  - generated_transaction
  - global_property
  - key_value
  - permission
  - permission_link
  - protocol_state
  - received_block  
  - resource_limits
  - resource_limits_config
  - resource_limits_state
  - resource_usage
  - transaction_trace 
# Alpha Release

This is an alpha release of the EOSIO History Tools. It includes database fillers
(`fill-pg`, `fill-rocksdb`) which pull data from nodeos's State History Plugin, and a new
query engine (`wasm-ql-pg`, `wasm-ql-rocksdb`) which supports queries defined by wasm, along
with an emulation of the legacy `/v1/` RPC API.

This alpha release is designed to solicit community feedback. There are several potential
directions this toolset may take; we'd like feedback on which direction(s) may be most
useful. Please create issues about changes you'd like to see going forward.

Since this is an alpha release, it will likely have incompatible changes in the
future. Some of these may be driven by community feedback.

This release includes the following:

## Alpha 0.4.0

This release upgrades `fill-pg` to support `nodeos` v2.1.0. The remaining tools are still disabled and have not been upgraded.
The support for RocksDB is likely to be dropped entirely now that `nodeos` can use it as a backend store. The schema used by
`fill-pg` has changed. At present no data migration tool is available, so data may be manually migrated, regenerated by replaying
from the desired block number, or exist side by side in two schemas, with older blocks in the v0.3.0 schema and newer blocks in
the new schema.  Use of the `--pg-schema` option will facilitate the transition.  Schema differences include:

 * addition of version numbers in column names for fields which are part of versioned structures, e.g. in the `action_trace`
   table, `receipt_receiver` is now `receipt0_receiver`.
 * the addition of an action_trace_v1 table, where all new action traces are written
 * new columns in tables with fields from versioned structures indicating which version is populated for the row, named with
   the suffix `_variant_populated`.
 * addition of a key_value table for storing data from the new nodeos storage mechanism of the same name.

Full details of the differences can be found via diff of plain text backups of each schema using `pg_dump`, not included here
for brevity.

## Alpha 0.3.0

This release adds temporary workarounds to `fill-pg` to support Nodeos 2.0. It also disables the remaining tools. If you would
like to test rocksdb support or wasm-ql support, stick with Nodeos 1.8 and the Alpha 0.2.0 release of History Tools.

* Temporary `fill-pg` fixes
  * Removed the `global_property` table
  * Removed `new_producers` from the `block_info` table
* Temporarily disabled building everything except `fill-pg`

## Alpha 0.2.0

* There are now 2 self-contained demonstrations in public Docker images. See [container-demos](doc/container-demos.md) for details.
  * Talk: this demonstrates using wasm-ql to provide messages from on-chain conversations to clients in threaded order.
  * Partial history: this demonstrates some of wasm-ql's chain and token queries on data drawn from one of the public EOSIO networks.
* Added RocksDB and removed LMDB. This has the following advantages:
  * Filling outperforms both PostgreSQL and LMDB by considerable margins, both for partial history
    and for full history on large well-known chains.
  * Database size for full history is much smaller than PostgreSQL.
* Database fillers have a new option `--fill-trx` to filter transaction traces.
* Database fillers no longer need `--fill-skip-to` when starting from partial history.
* Database fillers now automatically reconnect to the State History Plugin.
* wasm-ql now uses a thread pool to handle queries. `--wql-threads` controls the thread pool size.
* wasm-ql now uses eos-vm instead of SpiderMonkey. This simplifies the build process.
* wasm-ql can now serve static files. Enabled by the new `--wql-static-dir` option.
* SHiP connection handling moved to `state_history_connection.hpp`. This file may aid users needing
  to write custom solutions which connect to the State History Plugin.

## fill-pg

`fill-pg` fills postgresql with data from nodeos's State History Plugin. It provides nearly all
data that applications which monitor the chain need. It provides the following:

* Header information from each block
* Transaction and action traces, including inline actions and deferred transactions
* Contract table history, at the block level
* Tables which track the history of chain state, including
  * Accounts, including permissions and linkauths
  * Account resource limits and usage
  * Contract code
  * Contract ABIs
  * Consensus parameters
  * Activated consensus upgrades

`fill-pg` keeps action data and contract table data in its original binary form. Future versions
may optionally support converting this to JSON.

To conserve space, `fill-pg` doesn't store blocks in postgresql. The majority of apps
don't need the blocks since:

* Blocks don't include inline actions and only include some deferred transactions. Most
  applications need to handle these, so should examine the traces instead. e.g. many transfers
  live in the inline actions and deferred transactions that blocks exclude.
* Most apps don't verify block signatures. If they do, then they should connect directly to
  nodeos's State History Plugin to get the necessary data. Note that contrary to
  popular belief, the data returned by the `/v1/get_block` RPC API is insufficient for
  signature verification since it uses a lossy JSON conversion.
* Most apps which currently use the `/v1/get_block` RPC API (e.g. `eosjs`) only need a tiny
  subset of the data within block; `fill-pg` stores this data. There are apps which use
  `/v1/get_block` incorrectly since their authors didn't realize the blocks miss
  critical data that their applications need.

`fill-pg` supports both full history and partial history (`trim` option). This allows users
to make their own tradeoffs. They can choose between supporting queries covering the entire
history of the chain, or save space by only covering recent history.

#### Getting Started

You can use the docker-compose file to see how fill-pg interacts with nodeos and postgresql.
For example, if you want to run fill-pg with some snapshot and setup one peer address, create a
.env file such as:

```
SNAPSHOT_FILE=/root/history-tools/snapshot-2021-03-05-10-eos-v4@0171570460.bin
PEER_ADDR=peer.main.alohaeos.com:9876
```

Then execute the command:

```
docker-compose up
```

And you will start seeing logs from the 3 containers, showing how they interact between each other.

Further customization can be achieved with other environment variables for example to set an specific
branch/commit for nodeos or history-tools, such as:

```
DOCKER_EOSIO_TAG=develop
DOCKER_HISTORY_TOOLS_TAG=935650a6fb9ca596affe0a3c42e6a1966675061d
```

You can also modify the provided docker-compose.yaml so that, for example, it takes more p2p peer addresses,
for example:

```
       ...
       - --p2p-peer-address=peer.main.alohaeos.com:9876
       - --p2p-peer-address=p2p.eosflare.io:9876
       - --p2p-peer-address=p2p.eosargentina.io:5222
       - --p2p-peer-address=eos-bp.index.pro:9876
       - --p2p-peer-address=eosbp-0.atticlab.net:9876
       - --p2p-peer-address=mainnet.eosarabia.net:3571
       ...
```

## wasm-ql-pg

EOSIO contracts store their data in a format which is convenient for them, but hard
on general-purpose query engines. e.g. the `/v1/get_table_rows` RPC API struggles to provide 
all the necessary query options that applications need. `wasm-ql-pg` allows contract authors
and application authors to design their own queries using the same 
[toolset](https://github.com/EOSIO/eosio.cdt) that they use to design contracts. This
gives them full access to current contract state, a history of contract state, and the
history of actions for that contract. `fill-pg` preserves this data in its original
format to support `wasm-ql-pg`.

wasm-ql supports two kinds of queries:
* Binary queries are the most flexible. A client-side wasm packs the query into a binary
  format, a server-side wasm running in wasm-ql executes the query then produces a result
  in binary format, then the client-side wasm converts the binary to JSON. The toolset
  helps authors create both wasms.
* An emulation of the `/v1/` RPC API.

We're considering dropping client-side wasms and switching the format of the first type
of query to JSON RPC, Graph QL, or another format. We're seeking feedback on this switch.

## combo-rocksdb, fill-rocksdb, wasm-ql-rocksdb

These function identically to `fill-pg` and `wasm-ql-pg`, but store data using RocksDB
instead of postgresql. Since RocksDB is an embedded database instead of a database server,
this option may be simpler to administer. RocksDB also saves space and fills quicker.

* `combo-rocksdb`: Fills the database and answers queries. Use this for queries against a live database.
* `fill-rocksdb`: Use this when filling a database for the first time. It fills faster
   than `combo-rocksdb` but can't answer queries. Switch to `combo-rocksdb` after the database
   catches up with the chain.
* `wasm-ql-rocksdb`: Rarely used. Queries a database that isn't being filled.

## Contributing

[Contributing Guide](./CONTRIBUTING.md)

[Code of Conduct](./CONTRIBUTING.md#conduct)

## License

[MIT](./LICENSE)

## Important

See [LICENSE](LICENSE) for copyright and license terms.

All repositories and other materials are provided subject to the terms of this [IMPORTANT](important.md) notice and you must familiarize yourself with its terms.  The notice contains important information, limitations and restrictions relating to our software, publications, trademarks, third-party resources, and forward-looking statements.  By accessing any of our repositories and other materials, you accept and agree to the terms of the notice.
