pragma solidity 0.5.8;
pragma experimental ABIEncoderV2;

/// @title StandardStaking
/// @dev A set of contracts for people to open stakes, and allow people to claim against them
/// @author Mark Beylin <mark.beylin@consensys.net>
contract StandardStaking {

  using SafeMath for uint256;

  /*
   * Structs
   */

  struct Stake {
    address payable staker; // The address of the user who controls the stake
    address payable[] arbiters; // An array of individuals who may rule on claims for the given stake
    uint stakeAmount; // The amount in wei which the user has staked
    uint arbiterFee; // The fee which is paid to the arbiter who rules on the claim
    uint griefingFee; // The fee which is paid to the winning side for the trouble of dealing with the claim
    bool active; // A boolean which stores whether a user's stake is active (ie has the funds and accepts claims)
    uint deadline; // A uint representing the time after which the staker may relinquish their stake
    Claim[] claims; // An array of Fulfillments which store the various submissions which have been made to the bounty
  }

  struct Claim {
    address payable claimant; // The address of the individual who created the claim
    address payable arbiter; // The address of the arbiter who ends up ruling on the claim
    uint claimAmount; // The amount of wei which the user seeks within the claim
    bool ruled; // A boolean which stores whether or not the claim has been ruled upon by one of the available arbiters
    bool correct; // A boolean which stores whether or not the claimant has been deemed correct in their claim
  }

  /*
   * Storage
   */

  Stake[] public stakes; // An array of stakes


  bool public callStarted; // Ensures mutex for the entire contract

  /*
   * Modifiers
   */

  modifier callNotStarted(){
    require(!callStarted);
    callStarted = true;
    _;
    callStarted = false;
  }

  modifier validateStakeArrayIndex(
    uint _index)
  {
    require(_index < numStakes);
    _;
  }

  modifier validateClaimArrayIndex(
    uint _stakeId,
    uint _index)
  {
    require(_index < stakes[_stakeId].claims.length);
    _;
  }

  modifier validateArbiterArrayIndex(
    uint _stakeId,
    uint _index)
  {
    require(_index < stakes[_stakeId].arbiters.length);
    _;
  }

  modifier onlyStaker(
  address _sender,
  uint _stakeId)
  {
  require(_sender == stakes[_stakeId].staker);
  _;
  }

  modifier isValidArbiter(
    address _sender,
    uint _stakeId,
    uint _arbiterId)
  {
    require(_sender ==
            stakes[_stakeId].arbiters[_arbiterId].submitter);
    _;
  }

  modifier onlyClaimant(
  address _sender,
  uint _stakeId,
  uint _claimId)
  {
    require(_sender ==
            bounties[_bountyId].contributions[_contributionId].contributor);
    _;
  }

  modifier isActive(
    uint _claimId)
  {
    require(claims[_claimId].active);
    _;
  }

  modifier claimNotRuled(
    uint _stakeId,
    uint _claimId)
  {
    require(!stakes[_stakeId].claims[_claimId].ruled);
    _;
  }

  modifier deadlineIsPassed(
    uint _stakeId)
  {
    require(stakes[_stakeId].deadline < now);
    _;
  }

  modifier deadlineAfterNow(
    uint _deadline)
  {
    require(_deadline > now);
    _;
  }

  modifier deadlineAfterCurrent(
    uint _stakeId,
    uint _deadline)
  {
    require(_deadline > stakes[_stakeId].deadline);
    _;
  }

  modifier stakeIsLargeEnough(
    uint _stakeAmount,
    uint _arbiterFee,
    uint _griefingFee)
  {
    require(_stakeAmount > (_arbiterFee + _griefingFee));
    _;
  }

  modifier atLeastOneArbiter(
    address payable[] _arbiters)
  {
    require(_arbiters.length > 0);
    _;
  }

  modifier verifyStakeDeposit(
    uint _stakeAmount)
  {
    require(msg.value == _stakeAmount);
    _;
  }

  modifier verifyClaimDeposit(
    uint _stakeId,
    uint _claimAmount)
  {
    require(msg.value == (_claimAmount +
                          stakes[_stakeId].arbiterFee +
                          stakes[_stakeId].griefingFee));
    _;
  }

  modifier claimNotTooLarge(
    uint _stakeId,
    uint _claimAmount)
  {
    // If the claimant's right, the staker loses (claim amount + arbiter fee + griefing fee), so we check they have enough
    require((_claimAmount +
             stakes[_stakeId].arbiterFee +
             stakes[_stakeId].griefingFee) <= stakes[_stakeId].stakeAmount);
    _;
  }

 /*
  * Public functions
  */

  constructor() public {
  }

  /// @dev createStake(): creates a new stake
  /// @param _sender the sender of the transaction issuing the bounty (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _issuers the array of addresses who will be the issuers of the bounty
  /// @param _approvers the array of addresses who will be the approvers of the bounty
  /// @param _data the IPFS hash representing the JSON object storing the details of the bounty (see docs for schema details)
  /// @param _deadline the timestamp which will become the deadline of the bounty
  /// @param _token the address of the token which will be used for the bounty
  /// @param _tokenVersion the version of the token being used for the bounty (0 for ETH, 20 for ERC20, 721 for ERC721)
  function createStake(
    address payable _staker,
    address payable[] _arbiters,
    uint _stakeAmount,
    uint _arbiterFee,
    uint _griefingFee,
    uint _deadline,
    string memory _data)
    public
    stakeIsLargeEnough(_stakeAmount, _arbiterFee, _griefingFee)
    atLeastOneArbiter(_arbiters)
    deadlineAfterNow(_deadline)
    verifyStakeDeposit(_stakeAmount)
    payable
    returns (uint)
  {
    stakes.push(Stake(_staker,
                      _arbiters,
                      _stakeAmount,
                      _arbiterFee,
                      _griefingFee,
                      true,
                      _deadline));

    emit StakeCreated((claims.length - 1),
                      _sender,
                      _arbiters,
                      _stakeAmount,
                      _arbiterFee,
                      _griefingFee,
                      _data, // Instead of storing the string on-chain, it is emitted within the event for easy off-chain consumption
                      _deadline);

    return ((stakes.length - 1));
  }


  /// @dev openClaim(): Allows users to contribute tokens to a given bounty.
  ///                    Contributing merits no privelages to administer the
  ///                    funds in the bounty or accept submissions. Contributions
  ///                    are refundable but only on the condition that the deadline
  ///                    has elapsed, and the bounty has not yet paid out any funds.
  ///                    All funds deposited in a bounty are at the mercy of a
  ///                    bounty's issuers and approvers, so please be careful!
  /// @param _sender the sender of the transaction issuing the bounty (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _bountyId the index of the bounty
  /// @param _amount the amount of tokens being contributed
  function openClaim(
    uint _stakeId,
    uint _claimAmount,
    string memory _data)
    public
    payable
    validateStakeArrayIndex(_stakeId)
    verifyClaimDeposit(_stakeId, _claimAmount)
    claimNotTooLarge(_stakeId, _claimAmount)
    callNotStarted
  {
    stakes[_stakeId].claims.push(Claim(msg.sender,
                                  address(0),
                                  _claimAmount,
                                  false,
                                  false));

    emit ClaimOpened(_stakeId,
                     stakes[_stakeId].claims.length - 1, // The new contributionId
                     msg.sender,
                     _claimAmount,
                     _data);
  }

  function ruleOnClaim(
    uint _stakeId,
    uint _claimId,
    uint _arbiterId,
    bool _correct,
    string memory _data)
    public
    payable
    validateStakeArrayIndex(_stakeId)
    validateClaimArrayIndex(_claimId)
    validateArbiterArrayIndex(_arbiterId)
    isValidArbiter(_stakeId, _arbiterId)
    claimNotRuled(_stakeId, _claimId)
    stakeStillValid(_stakeId)
    callNotStarted
  {
    Stake storage rulingStake = stakes[_stakeId];
    Claim storage rulingClaim = stakes[_stakeId].claims[_claimId];

    rulingClaim.ruled = true;
    rulingClaim.correct = _correct;
    rulingClaim.arbiter = msg.sender;

    if (correct) {
      // Claimant is correct...
      rulingStake.stakeAmount -= (rulingClaim.claimAmount +
                                  rulingStake.griefingFee +
                                  rulingStake.arbiterFee));
      rulingClaim.claimant.transfer(2 * rulingClaim.claimAmount +
                                    2 * rulingStake.griefingFee +
                                    rulingStake.arbiterFee);
    } else {
      // Staker is correct
      rulingStake.staker.transfer(rulingClaim.claimAmount +
                                  rulingStake.griefingFee);
    }

    msg.sender.send(rulingStake.arbiterFee);

    emit ClaimRuledUpon(_stakeId,
                           _claimId,
                           _arbiterId,
                           _correct
                           _data);
  }

  /// @dev reclaimStake(): Allows users to refund the contributions they've
  ///                            made to a particular bounty, but only if the bounty
  ///                            has not yet paid out, and the deadline has elapsed.
  /// @param _sender the sender of the transaction issuing the bounty (should be the same as msg.sender unless the txn is called by the meta tx relayer)
  /// @param _bountyId the index of the bounty
  /// @param _contributionId the index of the contribution being refunded
  function reclaimStake(
    uint _stakeId)
    public
    validateStakeArrayIndex(_stakeId)
    onlyStaker(_stakeId)
    deadlineIsPassed
    callNotStarted
  {
    stakes[_stakeId].refunded = true;
    stakes[_stakeId].staker.send(stakes[_stakeId].stakeAmount);

    emit StakeReclaimed(_stakeId);
  }

  function extendDeadline(
    uint _stakeId,
    uint _newDeadline)
    public
    validateStakeArrayIndex(_stakeId)
    onlyStaker(_stakeId)
    deadlineAfterCurrent(_stakeId, _newDeadline)
    callNotStarted
  {
      stakes[_stakeId].deadline = _newDeadline;

      emit DeadlineExtended(_stakeId, _newDeadline);
  }

  function addArbiter(
    uint _stakeId,
    address payable _newArbiter,)
    public
    validateStakeArrayIndex(_stakeId)
    onlyStaker(_stakeId)
  {
    stakes[_stakeId].arbiters(_newArbiter);

    emit ArbiterAdded(_stakeId, _newArbiter);
  }
  /*
   * Events
   */

  event StakeCreated(uint _stakeId, address payable _staker, _, address payable[] _arbiters, uint _stakeAmount, uint _arbiterFee, uint _griefingFee, string _data, uint _deadline);
  event ClaimOpened(uint _stakeId, uint _claimId, address payable _claimant, uint _claimAmount, string _data);
  event ClaimRuledUpon(uint _stakeId, uint _claimId, uint _arbiterId, bool _correct, string _data);
  event StakeReclaimed(uint _stakeId);
  event DeadlineExtended(uint _stakeId, uint _newDeadline);
  event ArbiterAdded(uint _stakeId, address _newArbiter);
}
