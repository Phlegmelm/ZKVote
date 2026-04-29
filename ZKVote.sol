// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IVerifier {
    function verify(bytes calldata _proof, bytes32[] calldata _publicInputs) external view returns (bool);
}

/**
 * @title ZKVote
 * @notice Anonymous voting contract using ZK proofs (UltraHonk / Barretenberg).
 *
 * Public inputs layout (must match circuit declaration order):
 *   index 0 — merkle_root  (bytes32)
 *   index 1 — nullifier    (bytes32)
 *
 * Voters prove membership in the Merkle tree without revealing their secret.
 * The nullifier prevents double-voting.
 */
contract ZKVote {
    // ── State ────────────────────────────────────────────────────────────────

    IVerifier public immutable verifier;

    /// @notice The Merkle root of the eligible voter set.
    bytes32 public immutable merkleRoot;

    /// @notice Voting window
    uint256 public immutable startTime;
    uint256 public immutable endTime;

    /// @notice Vote tallies
    uint256 public votesFor;
    uint256 public votesAgainst;

    /// @notice Nullifiers that have already voted (prevents double-voting)
    mapping(bytes32 => bool) public nullifierUsed;

    // ── Events ───────────────────────────────────────────────────────────────

    event VoteCast(bytes32 indexed nullifier, uint8 vote);

    // ── Errors ───────────────────────────────────────────────────────────────

    error VotingNotOpen();
    error InvalidProof();
    error AlreadyVoted();
    error InvalidVote();


    // ── Constructor ──────────────────────────────────────────────────────────

    constructor(
        address _verifier,
        bytes32 _merkleRoot,
        uint256 _startTime,
        uint256 _endTime
    ) {
        verifier    = IVerifier(_verifier);
        merkleRoot  = _merkleRoot;
        startTime   = _startTime;
        endTime     = _endTime;
    }

    // ── External ─────────────────────────────────────────────────────────────

    /**
     * @notice Cast a vote anonymously.
     * @param _proof     Raw proof bytes from `bb prove -t evm`.
     * @param _nullifier The voter's nullifier (prevents double-voting).
     * @param _vote      0 = against, 1 = for.
     */
    function castVote(
        bytes calldata _proof,
        bytes32 _nullifier,
        uint8   _vote
    ) external {
        // ── Guards ───────────────────────────────────────────────────────────

        if (block.timestamp < startTime || block.timestamp > endTime)
            revert VotingNotOpen();

        if (_vote > 1)
            revert InvalidVote();

        if (nullifierUsed[_nullifier])
            revert AlreadyVoted();

        // ── Build public inputs (must match circuit output order) ────────────
        // Circuit: merkle_root is pub input 0, nullifier is pub input 1

        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = merkleRoot;
        publicInputs[1] = _nullifier;

        // ── Verify proof ─────────────────────────────────────────────────────

        if (!verifier.verify(_proof, publicInputs))
            revert InvalidProof();

        // ── Record vote ──────────────────────────────────────────────────────

        nullifierUsed[_nullifier] = true;

        if (_vote == 1) {
            votesFor++;
        } else {
            votesAgainst++;
        }

        emit VoteCast(_nullifier, _vote);
    }

    // ── Views ────────────────────────────────────────────────────────────────

    /// @notice Returns (votesFor, votesAgainst, totalVotes).
    function results() external view returns (uint256 _for, uint256 _against, uint256 total) {
        _for     = votesFor;
        _against = votesAgainst;
        total    = votesFor + votesAgainst;
    }

    /// @notice True if voting is currently open.
    function isOpen() external view returns (bool) {
        return block.timestamp >= startTime && block.timestamp <= endTime;
    }
}
