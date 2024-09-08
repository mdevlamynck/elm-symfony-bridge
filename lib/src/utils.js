import crypto from 'node:crypto';

let memoDict = {};

async function callElm(elm, args) {
    return new Promise((resolve, reject) => {
        const id = randomId();

        const subscription = data => {
            if (data.id !== id) {
                return;
            }

            elm.ports.sendToJs.unsubscribe(subscription);
            resolve(data);
        }

        elm.ports.sendToJs.subscribe(subscription);

        args.id = id;
        elm.ports.sendToElm.send(args);
    });
}

function randomId() {
    return Math.random().toString(32);
}

async function whenChanged(key, value, callback) {
    const previousHash = memoDict[key] || '';
    const newHash = crypto.createHash('sha1').update(value).digest("hex");

    if (previousHash == newHash) {
        return;
    } else {
        memoDict[key] = newHash;
        await callback();
    }
}

function error(msg, cause) {
    if (cause) {
        console.error(`[ERROR elm-symfony-bridge] ${msg}: ${cause}`);
    } else {
        console.error(`[ERROR elm-symfony-bridge] ${msg}`);
    }
}

module.exports = {
    callElm,
    whenChanged,
    error,
};
