#[starknet::interface]
pub trait IProofVerifier<TContractState> {
    fn verify_proof(
        self: @TContractState,
        proof: Array<felt252>,
        public_inputs: Array<felt252>,
    ) -> bool;
}

#[starknet::contract]
mod PrivateVoting {
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use super::IProofVerifierDispatcher;

    #[storage]
    struct Storage {
        verifier: ContractAddress,
        admin: ContractAddress,
        election_id: felt252,
        merkle_root: felt252,
        voting_open: bool,
        used_nullifier_by_election: LegacyMap<(felt252, felt252), bool>,
        vote_commitments: LegacyMap<(felt252, u64), felt252>,
        vote_count_by_election: LegacyMap<felt252, u64>,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        VoteAccepted: VoteAccepted,
        RootUpdated: RootUpdated,
        VotingOpened: VotingOpened,
        VotingClosed: VotingClosed,
        VerifierUpdated: VerifierUpdated,
    }

    #[derive(Drop, starknet::Event)]
    struct VoteAccepted {
        election_id: felt252,
        nullifier_hash: felt252,
        vote_commitment: felt252,
        index: u64,
    }

    #[derive(Drop, starknet::Event)]
    struct RootUpdated {
        election_id: felt252,
        new_root: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct VotingOpened {
        election_id: felt252,
        merkle_root: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct VotingClosed {
        election_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    struct VerifierUpdated {
        verifier: ContractAddress,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        verifier: ContractAddress,
        admin: ContractAddress,
    ) {
        assert(verifier.into() != 0, 'INVALID_VERIFIER');
        assert(admin.into() != 0, 'INVALID_ADMIN');

        self.verifier.write(verifier);
        self.admin.write(admin);
        self.voting_open.write(false);
    }

    fn assert_admin(self: @ContractState) {
        assert(get_caller_address() == self.admin.read(), 'ONLY_ADMIN');
    }

    #[external(v0)]
    fn set_verifier(ref self: ContractState, verifier: ContractAddress) {
        assert_admin(@self);
        assert(verifier.into() != 0, 'INVALID_VERIFIER');

        self.verifier.write(verifier);
        self.emit(VerifierUpdated { verifier });
    }

    #[external(v0)]
    fn open_voting(ref self: ContractState, election_id: felt252, merkle_root: felt252) {
        assert_admin(@self);
        assert(!self.voting_open.read(), 'ALREADY_OPEN');
        assert(election_id != 0, 'INVALID_ELECTION');
        assert(merkle_root != 0, 'INVALID_ROOT');

        self.election_id.write(election_id);
        self.merkle_root.write(merkle_root);
        self.voting_open.write(true);

        self.emit(VotingOpened { election_id, merkle_root });
    }

    #[external(v0)]
    fn close_voting(ref self: ContractState) {
        assert_admin(@self);
        assert(self.voting_open.read(), 'NOT_OPEN');

        self.voting_open.write(false);
        self.emit(VotingClosed {
            election_id: self.election_id.read(),
        });
    }

    #[external(v0)]
    fn update_root(ref self: ContractState, merkle_root: felt252) {
        assert_admin(@self);
        assert(self.voting_open.read(), 'NOT_OPEN');
        assert(merkle_root != 0, 'INVALID_ROOT');

        let election_id = self.election_id.read();
        self.merkle_root.write(merkle_root);
        self.emit(RootUpdated {
            election_id,
            new_root: merkle_root,
        });
    }

    #[external(v0)]
    fn cast_vote(
        ref self: ContractState,
        nullifier_hash: felt252,
        vote_commitment: felt252,
        proof: Array<felt252>,
    ) {
        assert(self.voting_open.read(), 'VOTING_CLOSED');
        assert(proof.len() > 0, 'EMPTY_PROOF');
        assert(nullifier_hash != 0, 'INVALID_NULLIFIER');
        assert(vote_commitment != 0, 'INVALID_COMMITMENT');

        let election_id = self.election_id.read();
        let nullifier_key = (election_id, nullifier_hash);
        assert(!self.used_nullifier_by_election.read(nullifier_key), 'NULLIFIER_USED');

        let merkle_root = self.merkle_root.read();

        let mut public_inputs = array![];
        public_inputs.append(election_id);
        public_inputs.append(merkle_root);
        public_inputs.append(nullifier_hash);
        public_inputs.append(vote_commitment);

        let verifier_dispatcher = IProofVerifierDispatcher {
            contract_address: self.verifier.read(),
        };

        let ok = verifier_dispatcher.verify_proof(proof, public_inputs);
        assert(ok, 'INVALID_PROOF');

        self.used_nullifier_by_election.write(nullifier_key, true);

        let idx = self.vote_count_by_election.read(election_id);
        self.vote_commitments.write((election_id, idx), vote_commitment);
        self.vote_count_by_election.write(election_id, idx + 1);

        self.emit(VoteAccepted {
            election_id,
            nullifier_hash,
            vote_commitment,
            index: idx,
        });
    }

    #[view]
    fn has_voted(self: @ContractState, election_id: felt252, nullifier_hash: felt252) -> bool {
        self.used_nullifier_by_election.read((election_id, nullifier_hash))
    }

    #[view]
    fn get_vote_count(self: @ContractState, election_id: felt252) -> u64 {
        self.vote_count_by_election.read(election_id)
    }

    #[view]
    fn get_vote_commitment(self: @ContractState, election_id: felt252, idx: u64) -> felt252 {
        self.vote_commitments.read((election_id, idx))
    }

    #[view]
    fn get_election_state(self: @ContractState) -> (bool, felt252, felt252) {
        (
            self.voting_open.read(),
            self.election_id.read(),
            self.merkle_root.read(),
        )
    }
}
