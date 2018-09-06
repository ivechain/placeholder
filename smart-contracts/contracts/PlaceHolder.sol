pragma solidity ^0.4.23;

import "./Owner.sol";

contract PlaceHolder is Owner {

    //排行榜手续费（目前1%）,手续费至少0.0001 ether
    uint public rankingFeePercent = 1;
    uint public rankingFeeMinimumAmount = 0.0001 ether;
    //系统最小押金
    uint public systemMinDeposit = 0.01 ether;
    //系统最小押金时间
    uint public systemMinDepositTime = 1 days;
    //押金时间上限
    uint public systemMaxDepositTime = 365 days;
    //位置数上限
    uint public systemMaxPlace = 255;
    //最小位置数
    uint public systemMinPlace = 1;

    uint256 public UID = 100000;

    //系统可提现余额
    uint private systemBalance = 0 ether;



    //排行榜信息
    struct RankingInfo {
        uint id;
        bytes32 name;//排行榜名称
        bytes32 describe;//排行榜描述
        bool state;//排行榜状态        启用true/禁用false
        uint8 mode;//优先抢位0/竞价抢位1
        address owner; //创建排行榜的用户地址
        uint positionNumber;//位置数
        uint minDeposit;//最少押金
        uint depositDays;//押金时间
        uint freezingTime;//提前下榜冻结时间
        uint time;//排行榜时间
    }

    //排行项信息
    struct Ranking {
        address userAddress; //用户地址（钱包地址）
        uint256 wealth;    //财富
        bytes32 remarks;   //备注
        uint time;//上榜时间
        uint freezeTime; //冻结时间
        uint8 status; //0下榜，1 上榜 2 冻结
    }

    //排行榜
    mapping(uint => mapping(address => Ranking)) RankingMap;
    mapping(uint => uint) RankingLength;
    //排行榜信息（key:排行榜id value:排行榜信息）
    mapping(uint => RankingInfo) RankingInfoMap;
    //排行榜拥有者（用户地址=>id[]）
    mapping(address => uint[]) RankingInfoOwner;

    //榜单变动事件
    event RankingEvent(address userAddress, uint256 wealth, bytes32 remarks, uint time, uint freezeTime, uint8 status, address operator, uint rId);
    //排行榜信息变动事件
    event RankingInfoEvent(uint id, bytes32 name, bytes32 describe, bool state, uint8 mode, address owner,
        uint positionNumber, uint minDeposit, uint depositDays, uint freezingTime, uint time, address operator);

    //排行榜手续费百分比
    function setRankingFeePercent(uint percent) public onlyOwner {
        rankingFeePercent = percent;
    }
    //手续费至少0.0001 ether
    function setRankingFeeMinimumAmount(uint _ether) public onlyOwner {
        rankingFeeMinimumAmount = _ether;
    }
    //系统最小押金
    function setSystemMinDeposit(uint _ether) public onlyOwner {
        systemMinDeposit = _ether;
    }
    //系统押金时间
    function setSystemDepositTime(uint minTime, uint maxTime) public onlyOwner {
        systemMinDepositTime = minTime;
        systemMaxDepositTime = maxTime;
    }
    //排行榜位置上下限
    function setSystemPlace(uint minPositionNumber, uint maxPositionNumber) public onlyOwner {
        systemMaxPlace = maxPositionNumber;
        systemMinPlace = minPositionNumber;
    }
    //创建排行榜
    function createRankingInfo(bytes32 name, bytes32 describe, uint8 mode, uint positionNumber, uint minDeposit, uint depositDays, uint freezingTime) public {

        require(name != "", "排行榜名称不能为空");
        require(describe != "", "排行榜描述不能为空");
        require(minDeposit > systemMinDeposit, "小于系统最小押金");
        require(depositDays > systemMinDepositTime, "小于系统最小押金时间");
        require(depositDays < systemMaxDepositTime, "大于系统上限押金时间");
        require(positionNumber > systemMinPlace, "小于最小位置数");
        require(positionNumber < systemMaxPlace, "大于最大位置数");
        require(depositDays > freezingTime, "冻结时间大于押金时间");

        uint _time = now;
        uint _id = UID++;
        RankingInfoMap[_id] = RankingInfo({
            id : _id,
            name : name,
            describe : describe,
            state : true,
            mode : mode,
            owner : msg.sender,
            positionNumber : positionNumber,
            minDeposit : minDeposit,
            depositDays : depositDays,
            freezingTime : freezingTime,
            time : _time
            });
        RankingInfoOwner[msg.sender].push(_id);

        emit RankingInfoEvent(_id, name, describe, true, mode, msg.sender, positionNumber, minDeposit, depositDays, freezingTime, _time, msg.sender);
    }

    //修改排行榜信息
    function modifyRankingInfo(uint id, uint positionNumber, uint minDeposit, uint depositDays, uint freezingTime, bytes32 describe, bool state) public {


        require(minDeposit > systemMinDeposit, "小于系统最小押金");
        require(depositDays > systemMinDepositTime, "小于系统最小押金时间");
        require(depositDays < systemMaxDepositTime, "大于系统上限押金时间");
        require(positionNumber > systemMinPlace, "小于最小位置数");
        require(positionNumber < systemMaxPlace, "大于最大位置数");
        require(depositDays > freezingTime, "冻结时间大于押金时间");
        require(describe != "", "排行榜描述不能为空");
        require(state == true || state == false, "状态应为bool类型");

        RankingInfo storage rankingInfo = RankingInfoMap[id];
        require(id == rankingInfo.id, "您的id有误！");

        rankingInfo.positionNumber = positionNumber;
        rankingInfo.minDeposit = minDeposit;
        rankingInfo.depositDays = depositDays;
        rankingInfo.freezingTime = freezingTime;
        rankingInfo.describe = describe;
        rankingInfo.state = state;

        emit RankingInfoEvent(rankingInfo.id, rankingInfo.name, describe, state, rankingInfo.mode, rankingInfo.owner, positionNumber, minDeposit, depositDays, freezingTime, rankingInfo.time, msg.sender);
    }

    //用户上榜
    function recharge(bytes32 remarks, uint rId)
    public
    payable {
        address userAddress = msg.sender;
        uint256 wealth = msg.value;

        Ranking storage ranking = RankingMap[rId][userAddress];
        RankingInfo storage rankingInfo = RankingInfoMap[rId];


        require(rId == rankingInfo.id, "您的id有误！");
        require(remarks != "", "备注不能为空");
        require(rankingInfo.state == true, "排行榜未开启");

        //加价
        if (ranking.userAddress == userAddress) {
            uint256 _wealth = ranking.wealth + wealth;
            require(_wealth > ranking.wealth, "押金溢出");
            ranking.remarks = remarks;
            ranking.wealth = _wealth;
            emit RankingEvent(ranking.userAddress, ranking.wealth, ranking.remarks, ranking.time, ranking.freezeTime, ranking.status, msg.sender, rId);
            return;
        }

        require(wealth > systemMinDeposit, "您的押金太少！");
        // 0代表优先抢位   1代表竞价抢位
        if (rankingInfo.mode == 0) {
            _priorityRobbing(userAddress, wealth, remarks, rId);
        } else {
            _biddingPosition(userAddress, wealth, remarks, rId);
        }
    }

    //优先抢位 （内部方法）
    function _priorityRobbing(address userAddress, uint256 wealth, bytes32 remarks, uint rId) private {

        //判断是否有空位1
        RankingInfo storage rankingInfo = RankingInfoMap[rId];
        require(RankingLength[rId] < rankingInfo.positionNumber, "没有空位");

        uint256 _time = now;
        RankingMap[rId][userAddress] = Ranking({
            userAddress : userAddress,
            wealth : wealth,
            remarks : remarks,
            time : _time,
            freezeTime : 0,
            status : 1
            });
        RankingLength[rId] += 1;

        emit RankingEvent(userAddress, wealth, remarks, _time, 0, 1, msg.sender, rId);
    }

    //竞价抢位
    function _biddingPosition(address userAddress, uint256 wealth, bytes32 remarks, uint rId) private {
        uint256 _time = now;
        RankingMap[rId][userAddress] = Ranking({
            userAddress : userAddress,
            wealth : wealth,
            remarks : remarks,
            time : _time,
            freezeTime : 0,
            status : 1

            });
        RankingLength[rId] += 1;

        emit RankingEvent(userAddress, wealth, remarks, _time, 0, 1, msg.sender, rId);
    }

    //下榜
    function retreat(uint rId) public {
        RankingInfo memory rankingInfo = RankingInfoMap[rId];
        require(rId == rankingInfo.id, "排行榜不存在，请验证排行榜唯一标识！");

        Ranking storage ranking = RankingMap[rId][msg.sender];
        //校验用户是否已经下榜
        require(ranking.status != 0, "您已经下榜了，请不要重复操作！");

        uint currentTime = now;
        if (ranking.status == 1 && currentTime < ranking.time + rankingInfo.depositDays) {//未过押金时间
            //计算冻结时间，自动下榜最大冻结时间不超过准许下榜时间
            uint mayFreezingTime = currentTime + rankingInfo.freezingTime;
            uint maxFreezingTime = ranking.time + rankingInfo.depositDays;
            ranking.freezeTime = mayFreezingTime > maxFreezingTime? maxFreezingTime: mayFreezingTime;

            RankingLength[rId] -= 1;
            ranking.status = 2;
            RankingMap[rId][ranking.userAddress] = ranking;
            emit RankingEvent(ranking.userAddress, ranking.wealth, ranking.remarks, ranking.time, ranking.freezeTime, ranking.status, msg.sender, rId);
        } else if (ranking.status == 1 || (ranking.status == 2 && currentTime >= ranking.freezeTime)) {//满足正常退押金
            if (ranking.status == 1) {
                RankingLength[rId] -= 1;
            }

            //计算费用
            uint256 fee = _calcFee(ranking.wealth);
            //给用户退款
            ranking.userAddress.transfer(ranking.wealth - fee);

            delete RankingMap[rId][ranking.userAddress];
            emit RankingEvent(ranking.userAddress, ranking.wealth, ranking.remarks, ranking.time, ranking.freezeTime, ranking.status, msg.sender, rId);
        } else if (ranking.status == 2 && currentTime < ranking.freezeTime) {//处于冻结状态
            emit RankingEvent(ranking.userAddress, ranking.wealth, ranking.remarks, ranking.time, ranking.freezeTime, ranking.status, msg.sender, rId);
        }
    }

    //计算费用
    function _calcFee(uint256 wealth) private returns (uint256){
        //计算费用
        uint feePercent = wealth * rankingFeePercent / 100;
        uint256 fee = feePercent >= rankingFeeMinimumAmount ? feePercent : rankingFeeMinimumAmount;
        systemBalance += fee;
        return fee;
    }

    //强制下榜冻结，重置冻结时间
    function frozen(uint rId, address userAddress) public {
        RankingInfo storage rankingInfo = RankingInfoMap[rId];
        //校验榜主
        require(msg.sender == rankingInfo.owner, "您不是合约拥有者");

        Ranking storage ranking = RankingMap[rId][userAddress];
        //校验用户是否下榜
        require(ranking.status != 0, "用户已经下榜！");

        if (ranking.status == 1) {
            RankingLength[rId] -= 1;
        }

        ranking.status = 2;
        ranking.freezeTime = now + 7 days;

        emit RankingEvent(ranking.userAddress, ranking.wealth, ranking.remarks, ranking.time, ranking.freezeTime, ranking.status, msg.sender, rId);
    }

    //管理员解冻
    function unFrozen(uint rId, address userAddress) public {
        RankingInfo storage rankingInfo = RankingInfoMap[rId];
        //校验榜主
        require(msg.sender == rankingInfo.owner, "您不是合约拥有者");

        Ranking storage ranking = RankingMap[rId][userAddress];
        //校验用户是否冻结
        require(ranking.status == 2, "用户不是冻结状态！");

        //计算费用
        uint256 fee = _calcFee(ranking.wealth);
        //给用户退款
        ranking.userAddress.transfer(ranking.wealth - fee);

        delete RankingMap[rId][ranking.userAddress];
        emit RankingEvent(ranking.userAddress, ranking.wealth, ranking.remarks, ranking.time, ranking.freezeTime, ranking.status, msg.sender, rId);
    }
    //提现 todo dao问题
    function withdraw() public onlyOwner {
        owner.transfer(systemBalance);
        systemBalance = 0 ether;
    }

    //合约销毁
    function kill() onlyOwner external {
        if (owner == msg.sender) {// 检查谁在调用
            selfdestruct(owner);
            // 销毁合约
        }
    }

}