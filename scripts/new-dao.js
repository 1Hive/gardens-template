const GardensTemplate = artifacts.require("GardensTemplate")

const DAO_ID = "05" // Note this must be unique for each deployment, change it for subsequent deployments
const INITIAL_SUPERVISOR = "0xb4124cEB3451635DAcedd11767f004d8a28c6eE7"
const NETWORK_ARG = "--network"
const DAO_ID_ARG = "--daoid"

const argValue = (arg, defaultValue) => process.argv.includes(arg) ? process.argv[process.argv.indexOf(arg) + 1] : defaultValue

const network = () => argValue(NETWORK_ARG, "local")
const daoId = () => argValue(DAO_ID_ARG, DAO_ID)

const gardensTemplateAddress = () => {
  if (network() === "rinkeby") {
    const Arapp = require("../arapp")
    return Arapp.environments.rinkeby.address
  } else if (network() === "mainnet") {
    const Arapp = require("../arapp")
    return Arapp.environments.mainnet.address
  } else {
    const Arapp = require("../arapp_local")
    return Arapp.environments.devnet.address
  }
}

const SUPPORT_REQUIRED = 50e16 // 50%
const MIN_ACCEPTANCE_QUORUM = 20e16 // 20%
const VOTE_DURATION_BLOCKS = 15
const VOTE_BUFFER_BLOCKS = 10
const VOTE_EXECUTION_DELAY_BLOCKS = 5
const VOTING_SETTINGS = [SUPPORT_REQUIRED, MIN_ACCEPTANCE_QUORUM, VOTE_DURATION_BLOCKS, VOTE_BUFFER_BLOCKS, VOTE_EXECUTION_DELAY_BLOCKS]

module.exports = async (callback) => {
  try {
    const gardensTemplate = await GardensTemplate.at(gardensTemplateAddress())

    const createDaoReceipt = await gardensTemplate.createDao(
      "VoteToken",
      "VTT",
      daoId(),
      [INITIAL_SUPERVISOR],
      VOTING_SETTINGS,
      0,
      true,
      false
    );
    console.log(`DEBUG: ${createDaoReceipt.logs.find(x => x.event === "DEBUG")} `)
    console.log(`DAO address: ${createDaoReceipt.logs.find(x => x.event === "DeployDao").args.dao} Gas used: ${createDaoReceipt.receipt.gasUsed} `)

  } catch (error) {
    console.log(error)
  }
  callback()
}
