/**
 * Created by wenxin on 2018/8/29.
 */
var PlaceHolder = artifacts.require("./PlaceHolder.sol");

module.exports = function (deployer) {
    deployer.deploy(PlaceHolder);
};
