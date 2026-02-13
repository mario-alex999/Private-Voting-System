# Private Voting System (Starknet + Noir + Garaga)

Plug-and-play **fullstack scaffold** for private voting in DAOs, schools, and communities.

## Stack
- **Noir** circuit for ZK proving logic.
- **Cairo/Starknet** contracts for verification orchestration and election state.
- **React + Vite + starknet.js** web app for wallet connection and vote submission.

## Monorepo layout
- `circuits/private_vote.nr` — Noir private voting circuit.
- `contracts/src/private_voting.cairo` — Voting contract that calls a verifier contract.
- `contracts/src/mock_verifier.cairo` — Local verifier stub for integration testing.
- `contracts/src/lib.cairo` — Contract module entrypoint.
- `Scarb.toml` — Cairo package configuration.
- `frontend/` — Starknet frontend scaffold.
- `docs/research-and-plan.md` — architecture notes.
- `scripts/public_inputs_order.md` — canonical public input ordering.

## Quickstart

### 1) Cairo contracts
```bash
scarb build
```

### 2) Frontend
```bash
cd frontend
cp .env.example .env
npm install
npm run dev
```

Set `VITE_PRIVATE_VOTING_ADDRESS` in `.env` to your deployed `PrivateVoting` address.

## Public input order (must match circuit + verifier)
1. `election_id`
2. `merkle_root`
3. `nullifier_hash`
4. `vote_commitment`

## Note for dev team
The ZK circuit is written in **Noir (not Cairo)**. Cairo is used for on-chain contracts and verifier integration.


## Starknet scaffold notes
This repository is structured as a Starknet fullstack scaffold:
- Scarb-managed Cairo contracts in `contracts/src`.
- React/Vite frontend in `frontend/` consuming Starknet RPC + wallet APIs.
- Noir circuit artifacts kept separate from app runtime.

Suggested next steps to complete a production scaffold:
1. Add deployment scripts for `MockVerifier` / Garaga verifier + `PrivateVoting`.
2. Replace `frontend/src/abi.ts` with generated ABI JSON from compiled contract artifacts.
3. Add an indexer/relayer service to package proof calldata for users.
