# Aleo.store NFT Standard

Standard proposition for NFTs on Aleo. Documentation for the standard can be found [here](https://docs.aleo.store).

__Official marketplace frontend:__ [Aleo.store](https://aleo.store)

__Program ID:__ `aleo_store.aleo`

## Build Guide

To compile this program, run:
```bash
leo build
```

To execute this program, run:
```bash
leo run
```

To deploy this program, run in parent directory:
```bash
API="https://vm.aleo.org/api"
BROADCAST="testnet3/transaction/broadcast"
APPNAME="REPLACE_HERE_APPNAME"
PRIVATEKEY="REPLACE_HERE_PRIVATEKEY"
RECORD="REPLACE_HERE_FEE_RECORD"

snarkos developer deploy \
"${APPNAME}.aleo" \
--private-key "${PRIVATEKEY}" \
--query "${API}" \
--path "./${APPNAME}/build/" \
--broadcast "${API}/${BROADCAST}" \
--fee 0 \
--record "${RECORD}"
```
