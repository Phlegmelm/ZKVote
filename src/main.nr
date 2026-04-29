use ::std::hash::pedersen_hash;

fn hash_pair(left: Field, right: Field) -> Field {
    pedersen_hash([left, right])
}

fn compute_merkle_root(leaf: Field, index: Field, path: [Field; 3]) -> Field {
    let mut current = leaf;
    let mut idx = index as u64;

    for i in 0..3 {
        let is_right = idx % 2;
        if is_right == 1 {
            current = hash_pair(path[i], current);
        } else {
            current = hash_pair(current, path[i]);
        }
        idx = idx / 2;
    }
    current
}

fn main(
    secret: Field,
    vote: Field,
    index: Field,
    path: [Field; 3],
    merkle_root: pub Field,
    nullifier: pub Field,
) {
    let is_valid_vote = (vote == 0) | (vote == 1);
    assert(is_valid_vote, "vote must be 0 or 1");

    let leaf = pedersen_hash([secret]);
    let computed_root = compute_merkle_root(leaf, index, path);
    assert(computed_root == merkle_root, "not in voter set");

    let computed_nullifier = pedersen_hash([secret]);
    assert(computed_nullifier == nullifier, "invalid nullifier");
}

#[test]
fn test_print_values() {
    let secret: Field = 42;
    let leaf = pedersen_hash([secret]);
    println(f"leaf: {leaf}");

    /* fake siblings for a depth-3 tree */
    let path: [Field; 3] = [1, 2, 3];
    let index: Field = 0;

    /* compute root */
    let root = compute_merkle_root(leaf, index, path);
    println(f"root: {root}");

    /* nullifier */
    let nullifier = pedersen_hash([secret]);
    println(f"nullifier: {nullifier}");
}
