import routing from './routing.js';
import translations from './translations.js';

const atomic = new Int32Array(new SharedArrayBuffer(4));

module.exports = async function (global) {
    await onlyOnce(async () => {
        await Promise.all([
            routing.transpile(global),
            translations.transpile(global),
        ]);
    });
};

async function onlyOnce(callback) {
    const isLocked = lock();

    if (isLocked) {
        await waitUnlock();
    } else {
        try {
            await callback();
        } finally {
            unlock();
        }
    }
}

function lock() {
    return Atomics.compareExchange(atomic, 0, 0, 1);
}

async function waitUnlock() {
    await Atomics.waitAsync(atomic, 0, 1).value;
}

function unlock() {
    Atomics.store(atomic, 0, 0);
    Atomics.notify(atomic, 0);
}
