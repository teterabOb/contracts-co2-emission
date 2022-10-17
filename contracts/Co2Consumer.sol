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
        uint256 ctrRAirline;
        address airlineContract;
        uint256 roundId;
        uint256 co2Amount;
        uint256 startedAt;
        uint256 finishedAt;
        bytes32 requestId;
    }
    // ID Airline  -> (ID Record -> Co2Emission)
    mapping(uint256 => Co2Emission) private s_emissionHistory;
    mapping(address => Co2Emission) private s_lastEmissionByAirline;
    mapping(address => mapping(uint256 => Co2Emission))
        private s_emissionByAirline;
    mapping(address => bool) private s_contracts;
    mapping(address => bool) private s_contractsAllowedToCall;

    event RequestCo2Emission(Co2Emission indexed co2Emission);
    event ContractAdded(address indexed airlineAddress);
    event ContractEnabled(address indexed airlineAddress);

    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0x5CeD5FE184f6504DFF3Ce899392f8019f4F580f6);
        jobId = "5b11b78a00bc4151b44909421c04524e"; // insert right jobID
        fee = (1 * LINK_DIVISIBILITY) / 10;
    }

    function requestCo2Emission(
        address _airlineContract,
        string memory _from,
        string memory _to,
        uint256 _passengers,
        string memory _classFlight
    ) external isAllowed(msg.sender) returns (bytes32 requestId) {
        require(_passengers <= 555, "Max num of passengers is 555");
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfill.selector
        );
        string memory _strPassengers = Strings.toString(_passengers);
        s_roundID.increment();
        uint256 currentId = s_roundID.current();

        Co2Emission memory lastEmission = s_lastEmissionByAirline[
            _airlineContract
        ];
        uint256 auxCtrRAirline = lastEmission.ctrRAirline;

        Co2Emission memory _co2 = Co2Emission(
            auxCtrRAirline++, // counter request by airline
            _airlineContract, // airline contract
            currentId, // current round id
            0, // co2 amount received in fallback function
            block.timestamp, // when round starts
            0, // when round finishes
            0 // request id received in fallback function
        );

        req.add("from", _from);
        req.add("to", _to);
        req.add("passengers", _strPassengers);
        req.add("classFlight", _classFlight);

        s_emissionHistory[currentId] = _co2;
        return sendChainlinkRequest(req, fee);
    }

    function fulfill(bytes32 _requestId, uint256 _co2e)
        public
        recordChainlinkFulfillment(_requestId)
    {
        uint256 currentId = s_roundID.current();
        Co2Emission memory _auxCo2 = s_emissionHistory[currentId];
        require(
            _auxCo2.finishedAt == 0 && _auxCo2.requestId == 0,
            "Error fulfill"
        );
        address airlineContract = _auxCo2.airlineContract;
        _auxCo2.co2Amount = _co2e;
        _auxCo2.requestId = _requestId;
        _auxCo2.finishedAt = block.timestamp;
        s_emissionHistory[currentId] = _auxCo2;
        s_emissionByAirline[airlineContract][_auxCo2.ctrRAirline] = _auxCo2;
        s_lastEmissionByAirline[airlineContract] = _auxCo2;
        emit RequestCo2Emission(_auxCo2);
    }

    /*
    function getLastEmissionByAirline(address _airlineContract) external view returns(Co2Emission memory){
        require(_airlineContract != address(0), "NO zero address");
        return s_lastEmissionByAirline[_airlineContract];
    }
    */

    function getLastEmissionByAirline(address _airlineContract)
        external
        view
        returns (
            uint,
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            bytes32
        )
    {
        require(_airlineContract != address(0), "NO zero address");
        Co2Emission memory co2Aux = s_lastEmissionByAirline[_airlineContract];
        return(
            co2Aux.ctrRAirline,
            co2Aux.airlineContract,
            co2Aux.roundId,
            co2Aux.co2Amount,
            co2Aux.startedAt,
            co2Aux.finishedAt,
            co2Aux.requestId
        );
    }

    function getEmissionByAirline(address _airlineContract, uint256 _id)
        external
        view
        returns (Co2Emission memory)
    {
        require(_airlineContract != address(0), "NO zero address");
        return s_emissionByAirline[_airlineContract][_id];
    }

    function getEmissionById(uint256 _id)
        external
        view
        returns (Co2Emission memory)
    {
        return s_emissionHistory[_id];
    }

    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    function addAirline(address _address, bool _enableAirline)
        external
        onlyOwner
    {
        s_contracts[_address] = true;
        if (_enableAirline) _enableContract(_address);
        emit ContractAdded(_address);
    }

    function enableContract(address _address)
        external
        airlineExists(_address)
        onlyOwner
    {
        _enableContract(_address);
        emit ContractEnabled(_address);
    }

    // ** Setter ** //
    function updateJobID(bytes32 _jobId) public onlyOwner {
        jobId = _jobId;
    }

    // ** Internal Functions ** //
    function _enableContract(address _address) internal {
        require(_airlineExists(_address), "Address not exists");
        s_contractsAllowedToCall[_address] = true;
    }

    function _isAllowed(address _address) internal view returns (bool) {
        return s_contractsAllowedToCall[_address];
    }

    function _airlineExists(address _address) internal view returns (bool) {
        return s_contracts[_address];
    }

    // ** Modifiers ** //
    modifier isAllowed(address _address) {
        require(_isAllowed(_address), "Contract not allowed");
        _;
    }

    modifier airlineExists(address _address) {
        require(_airlineExists(_address), "");
        _;
    }
}
