# Private Voting on Starknet with Noir + Garaga (Backend Research)

## Executive summary
For your use case (private identity, one-person-one-vote, verified counting on Starknet), the cleanest stack is:

1. **Circuit language: Noir** (not Cairo) for proving logic.
2. **Proof system** compatible with Garaga verifier generation.
3. **Garaga-generated Starknet verifier contract**.
4. **Starknet voting contract** that:
   - accepts proof + public inputs,
   - asks verifier to validate proof,
   - rejects reused nullifier hashes,
   - stores encrypted/committed vote payloads for off-chain tally or on-chain tally constraints.

> Important clarification for the dev team: **the ZK circuit in this design is written in Noir, not Cairo**. Cairo contracts are used for verification and state management on Starknet.

## Why Noir for the circuit
- Noir is expressive for constraint systems and resembles Rust-like/Cairo-like patterns for arithmetic constraints.
- You can encode boolean checks using field constraints (`x * (x - 1) == 0` style) and assertions.
- Better developer ergonomics for proving logic; Cairo remains ideal for on-chain Starknet contracts.

## Core privacy model
### Public inputs (visible on-chain)
- `election_id`
- `merkle_root` of eligible voter commitments
- `nullifier_hash` (prevents double-voting)
- `vote_commitment` (commit to vote without revealing plaintext)

### Private witness inputs (kept secret)
- voter secret (or identity secret)
- Merkle path proving membership in eligibility tree
- vote plaintext + randomness (if using commitment/encryption)

## Constraints proven in circuit
The proof should assert all of the following:
1. Voter belongs to authorized set (`MerklePath.verify(...) == true`).
2. `nullifier_hash = H(identity_secret, election_id)`.
3. `vote_commitment = H(vote, blinding_factor, election_id)` (or encrypted ballot hash).
4. Vote value is valid (e.g., binary: 0/1, or enum constraint).

This ensures correctness without exposing identity or actual vote.

## One-person-one-vote semantics
The circuit alone cannot enforce global uniqueness across all submissions. That is handled by Starknet state:
- Contract keeps `used_nullifiers: Map<felt252, bool>`.
- On valid proof:
  - if `used_nullifiers[nullifier_hash] == true` => reject.
  - else set to true and accept vote commitment.

This is the standard split:
- circuit: local correctness,
- contract: global anti-replay / anti-double-vote.

## Garaga integration outline
1. Compile Noir circuit and generate proving/verifying keys.
2. Produce proofs off-chain.
3. Use Garaga tooling to generate Starknet verifier contract from the verification key.
4. Deploy verifier contract on Starknet.
5. Deploy voting contract configured with verifier address.

## Suggested architecture for DAOs / schools / communities
- **Registry layer**: admin or governance sets election root + parameters.
- **Proof verifier layer**: Garaga-generated verifier contract.
- **Voting layer**: stores nullifiers and vote commitments.
- **Tally layer**:
  - Option A: off-chain decrypt/aggregate with audit trail.
  - Option B: additional ZK tally proof submission on-chain.

## Operational notes
- Domain-separate hashes by `election_id` and protocol version.
- Include chain id / contract address in signed contexts where needed.
- Use event logs for accepted votes and finalized tally commitments.
- Consider time windows (`start_block`, `end_block`) per election.

## Practical warning
Verifier contract generation/serialization formats are precision-sensitive. Keep versions pinned:
- Noir toolchain version
- proving backend version
- Garaga version
- Starknet/Cairo compiler version

Mismatches here are the biggest source of integration failures.
