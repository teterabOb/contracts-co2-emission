//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

import "./interface/ICo2Consumer.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Airline is Ownable {
    string private s_name;
    ICo2Consumer consumer;

    constructor(address _consumer) {
        consumer = ICo2Consumer(_consumer);
    }

    function requestEmission(
        string memory _from,
        string memory _to,
        uint256 _passengers,
        string memory _classFlight
    ) external onlyOwner {
        consumer.requestCo2Emission(
            address(this),
            _from,
            _to,
            _passengers,
            _classFlight
        );
    }

    function getLastRequest()
        public
        view
        returns (
            uint ctrRAirline,
            address airlineContract,
            uint256 roundId,
            uint256 co2Amount,
            uint256 startedAt,
            uint256 finishedAt,
            bytes32 requestId
        )
    {
        return consumer.getLastEmissionByAirline(address(this));
    }
}
