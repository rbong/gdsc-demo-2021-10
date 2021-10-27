const { Firestore } = require("@google-cloud/firestore");

const db = new Firestore();

/**
 * @swagger
 * definitions:
 *   Message:
 *     type: object
 *     required:
 *       - message
 *     properties:
 *       message:
 *         type: string
 *   Error:
 *     type: object
 *     required:
 *       - error
 *     properties:
 *       error:
 *         type: string
 */

/**
 * @swagger
 * /message:
 *   post:
 *     description: Set the current message.
 *     operationId: postMessage
 *     parameters:
 *       - name: message
 *         in: body
 *         required: true
 *         description: The new message.
 *         schema:
 *           $ref: "#/definitions/Message"
 *     responses:
 *       200:
 *         description: Success
 *         schema:
 *           $ref: "#/definitions/Message"
 *       500:
 *         description: Failure
 *         schema:
 *           $ref: "#/definitions/Error"
 *     x-google-backend:
 *       address: ${cloudfunction_host}/postMessage
 *       protocol: h2
 *     x-gdsc-function:
 *       name: postMessage
 */
async function postMessage(req, res) {
  const { message } = req.body;

  if (!message) {
    return res.status(500).send({ error: "Missing message" });
  }

  if (message.length > 256) {
    return res.status(500).send({ error: "Message too long" });
  }

  try {
    await db.collection("message").doc("0").set({ message });
  } catch (e) {
    console.error(e);
    return res.status(500).send({ error: "Internal database error" });
  }

  return res.status(200).send({ message });
}

/**
 * @swagger
 * /message:
 *   get:
 *     description: Get the current message.
 *     operationId: getMessage
 *     responses:
 *       200:
 *         description: Success
 *         schema:
 *           $ref: "#/definitions/Message"
 *       500:
 *         description: Failure
 *         schema:
 *           $ref: "#/definitions/Error"
 *     x-google-backend:
 *       address: ${cloudfunction_host}/getMessage
 *       protocol: h2
 *     x-gdsc-function:
 *       name: getMessage
 */
async function getMessage(req, res) {
  let doc;

  try {
    doc = await db.collection("message").doc("0").get();
  } catch (e) {
    console.error(e);
    return res.status(500).send({ error: "Internal database error" });
  }

  if (!doc.exists) {
    return res.status(500).send({ error: "No message yet" });
  }

  const { message } = doc.data();

  return res.status(200).send({ message });
}

module.exports = {
  postMessage,
  getMessage,
};
