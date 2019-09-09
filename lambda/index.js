/**
 * [description]
 * 
 */

const Batch = require('aws-sdk/clients/batch')
const uuid = require('uuid/v4')
const util = require('util')

const JOB_DEFINITION = process.env.JOB_DEFINITION
const JOB_QUEUE = process.env.JOB_QUEUE

const PREDICT_TABLE = process.env.PREDICT_TABLE

const client = new Batch()

exports.handler = async (event) => {
  console.log(util.inspect(event, { depth: 5 }))

  let result = {}

  try {
    let params = {
      jobDefinition: JOB_DEFINITION,
      jobName: uuid(),
      jobQueue: JOB_QUEUE,
      parameters: {
        dynamoTable: PREDICT_TABLE
      }
    }

    result = await client.submitJob(params).promise()
    console.log(`Started AWS Batch job ${result.jobId}`)
  } catch (error) {
    console.error(error)
    return error
  }

  return result
}