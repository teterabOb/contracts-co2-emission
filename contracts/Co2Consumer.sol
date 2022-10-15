// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract Co2Consumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;    
    using Counters for Counters.Counter;
    
    Counters.Counter public s_roundID;
    bytes32 private jobId;
    uint256 private fee;

    struct Co2Emission {
        address airlineContract;
        uint256 roundId;
        uint256 co2Amount;
        uint256 startedAt;
        uint256 finishedAt;
        bytes32 requestId;
    }
    // ID Airline  -> (ID Record -> Co2Emission)
    mapping(uint256 => Co2Emission) s_EmissionHistory;
    mapping(address => bool) s_contracts;
    mapping(address => bool) s_contractsAllowedToCall;

    event RequestCo2Emission(Co2Emission indexed co2Emission);
    event ContractAdded(address indexed airlineAddress);
    event ContractEnabled(address indexed airlineAddress);
    
    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0x5CeD5FE184f6504DFF3Ce899392f8019f4F580f6);
        jobId = "5b11b78a00bc4151b44909421c04524e"; // insert right jobID
        fee = (1 * LINK_DIVISIBILITY) / 10;    
    }

    function updateJobID(bytes32 _jobId) public onlyOwner{
        jobId = _jobId;        
    }

    function requestCo2Emission(
        address _airlineContract,
        string memory _from,
        string memory _to,
        uint _passengers,
        string memory _classFlight
    ) external  returns (bytes32 requestId) {
        require(_passengers <= 555, "Max num of passengers is 555");
        Chainlink.Request memory req = buildChainlinkRequest(jobId,address(this),this.fulfill.selector);
        string memory _strPassengers = Strings.toString(_passengers);
        s_roundID.increment();
        uint256 currentId = s_roundID.current();
        Co2Emission memory _co2 = 
            Co2Emission(
                _airlineContract // airline contract
                , currentId // current round id
                , 0 // co2 amount received in fallback function
                , block.timestamp // when round starts
                , 0 // when round finishes
                , 0 // request id received in fallback function
            );

        req.add("from", _from);
        req.add("to", _to);
        req.add("passengers", _strPassengers);
        req.add("classFlight", _classFlight);

        s_EmissionHistory[currentId] = _co2;
        return sendChainlinkRequest(req, fee);
    }


    function fulfill(bytes32 _requestId, uint256 _co2e) public recordChainlinkFulfillment(_requestId){        
        uint256 currentId = s_roundID.current();
        Co2Emission memory _auxCo2 = s_EmissionHistory[currentId];
        require(_auxCo2.finishedAt == 0 && _auxCo2.requestId == 0, "Error fulfill");
        _auxCo2.co2Amount = _co2e;
        _auxCo2.requestId = _requestId;
        _auxCo2.finishedAt = block.timestamp;
        s_EmissionHistory[currentId] = _auxCo2;
        emit RequestCo2Emission(_auxCo2);
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function addAirline(address _address, bool _enableAirline) external onlyOwner{
        s_contracts[_address] = true;
        if(_enableAirline) _enableContract(_address);
        emit ContractAdded(_address);
    }

    function enableContract(address _address) external airlineExists(_address) onlyOwner {
        _enableContract(_address);
        emit ContractEnabled(_address);
    }

    // ** Internal Functions ** //
    function _enableContract(address _address) internal {
        require(_airlineExists(_address), "Address not exists");
        s_contractsAllowedToCall[_address] = true;
    }

    function _isAllowed(address _address) internal view returns(bool){
        return s_contractsAllowedToCall[_address];
    }

    function _airlineExists(address _address) internal view returns(bool){
        return s_contracts[_address];
    }

    // ** Modifiers ** //
    modifier isAllowed(address _address){
        require(_isAllowed(_address), "Contract not allowed");
        _;
    }   

    modifier airlineExists(address _address) {
        require(_airlineExists(_address), "");
        _;
    } 

    function stringToUint(string memory s) internal pure returns (uint) {
        bytes memory b = bytes(s);
        uint result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 c = uint256(uint8(b[i]));
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
        return result;
    }
}
