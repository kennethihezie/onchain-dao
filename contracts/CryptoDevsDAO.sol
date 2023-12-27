// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IFakeNFTMarketplace.sol";
import "./ICryptoDevsNFT.sol";

contract CryptoDevsDAO is Ownable {
  struct Proposal {
     // nftTokenId - the tokenID of the NFT to purchase from 
     // FakeNFTMarketplace if the proposal passes
     uint256 nftTokenId;

      // deadline - the UNIX timestamp until which this proposal
      // is active. Proposal can be executed after the deadline has been exceeded.
      uint256 deadline;

      // yayVotes - number of yay votes for this proposal
      uint256 yayVotes;

      // nayVotes - number of nay votes for this proposal
      uint256 nayVotes;

     // executed - whether or not this proposal has been executed yet.
     // Cannot be executed before the deadline has been exceeded.
     bool excuted;

     // voters - a mapping of CryptoDevsNFT tokenIDs to booleans indicating
     // whether that NFT has already been used to cast a vote or not
     mapping (uint256 => bool) voters;
  }

  enum Vote {
    YAY, // YAY = 0
    NAY // NAY = 1
  }

  // Create a mapping of ID to Proposal
  mapping (uint256 => Proposal) public proposals;

  // Number of proposals that have been created
  uint256 public numProposals;

  IFakeNFTMarketplace nftMarketplace;
  ICryptoDevsNFT cryptoDevsNFT;

  // Create a payable constructor which initializes the contract
  // instances for FakeNFTMarketplace and CryptoDevsNFT
  // The payable allows this constructor to accept an ETH deposit when it is being deployed
  constructor(address _nftMarketplace, address _cryptoDevsNFT) payable Ownable(msg.sender) {
    nftMarketplace = IFakeNFTMarketplace(_nftMarketplace);
    cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
  }

  modifier nftHolderOnly() {
    require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "Not a DAO Member");
    _;
  }

  modifier activeProposalOnly(uint256 proposalIndex) {
    require(proposals[proposalIndex].deadline > block.timestamp, 'DEADLINE_EXCEEDED');
    _;
  }

  // Create a modifier which only allows a function to be
  // called if the given proposals' deadline HAS been exceeded
  // and if the proposal has not yet been executed
  modifier inactiveProposalOnly(uint256 proposalIndex) {
    require(proposals[proposalIndex].deadline <= block.timestamp, "DEADLINE_NOT_EXCEEDED");
    require(proposals[proposalIndex].excuted == false, "PROPOSAL_ALREADY_EXECUTED");
    _;
  }

  /// @dev createProposal allows a CryptoDevsNFT holder to create a new proposal in the DAO
  /// @param _nftTokenId - the tokenID of the NFT to be purchased from FakeNFTMarketplace if this proposal passes
  /// @return Returns the proposal index for the newly created proposal
  function createProposal(uint256 _nftTokenId) external nftHolderOnly  returns (uint256) {
     require(nftMarketplace.available(_nftTokenId), 'Nft Not for sale');
     Proposal storage proposal = proposals[numProposals];
     proposal.nftTokenId = _nftTokenId;

     // Set the proposal's voting deadline to be (current time + 5 minutes)
     proposal.deadline = block.timestamp + 5 minutes;
     numProposals++;

     return numProposals - 1;
  }

  /// @dev voteOnProposal allows a CryptoDevsNFT holder to cast their vote on an active proposal
  /// @param proposalIndex - the index of the proposal to vote on in the proposals array
  /// @param vote - the type of vote they want to cast  
  function voteOnProposal(uint256 proposalIndex, Vote vote) external nftHolderOnly activeProposalOnly(proposalIndex) {
    Proposal storage proposal = proposals[proposalIndex];
    uint256 voterNftBalance = cryptoDevsNFT.balanceOf(msg.sender);
    uint256 numVotes = 0;
    
    // Calculate how many NFTs are owned by the voter
    // that haven't already been used for voting on this proposal
    for (uint256 i = 0; i < voterNftBalance; i++) {
        uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
        if (proposal.voters[tokenId] == false) {
            numVotes++;
            proposal.voters[tokenId] = true;
        }
    }

    require(numVotes > 0, 'ALREADY_VOTED');

    if(vote == Vote.YAY){
        proposal.yayVotes += numVotes;
    } else {
        proposal.nayVotes += numVotes;
    }
  }

  /// @dev executeProposal allows any CryptoDevsNFT holder to execute a proposal after 
  /// it's deadline has been exceeded
  /// @param proposalIndex - the index of the proposal to execute in the proposals array
  function executeProposal(uint256 proposalIndex) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
    Proposal storage proposal = proposals[proposalIndex];

    // If the proposal has more YAY votes than NAY votes
    // purchase the NFT from the FakeNFTMarketplace
    if(proposal.yayVotes > proposal.nayVotes) {
        uint256 nftPrice = nftMarketplace.getPrice();
        require(address(this).balance >= nftPrice, "NOT_ENOUGH_FUNDS");
        nftMarketplace.purchase{ value: nftPrice }(proposal.nftTokenId);
    }

    proposal.excuted = true;
  }

  // The Ownable contract we inherit from, contains a modifier onlyOwner which
  // restricts a function to only be able to be called by the contract owner.
  function withdrawEther() external onlyOwner {
    uint256 amount = address(this).balance;
    require(amount > 0, "Nothing to withdraw, contract balance empty");
    (bool sent, bytes memory data) = payable(owner()).call{ value: amount }("");
    require(sent, "FAILED_TO_WITHDRAW_ETHER");
  }

  // Finally, to allow for adding more ETH deposits to the DAO treasury, we need to
  // add some special functions. Normally, contract addresses cannot accept
  // ETH sent to them, unless it was through a payable function. But we don't want
  // users to call functions just to deposit money, they should be able to transfer
  // ETH directly from their wallet. For that, let's add these two functions:
  // The following two functions allow the contract to accept ETH deposits
  // directly from a wallet without calling a function
  receive() external payable {}

  fallback() external payable {}  
}