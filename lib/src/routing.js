import fs from './filesystem.js';
import symfony from './symfony.js';
import utils from './utils.js';

function transpile(global, callback = null) {
    if (!global.options.enableRouting) {
        if (typeof callback === 'function') {
            callback();
        }

        return;
    }

    console.time('[PERF] routing cmd');
    let content = symfony.queryRouting(global.options);
    console.timeEnd('[PERF] routing cmd');

    console.time('[PERF] routing elm');
    const elmSubscription = data => {
        if (data.type !== 'routing') {
            return;
        }

        if (data.succeeded) {
            fs.writeIfChanged(global.options.elmRoot + '/Routing.elm', data.content);
        } else {
            utils.error(data.error)
        }

        global.transpiler.ports.sendToJs.unsubscribe(elmSubscription);
        console.timeEnd('[PERF] routing elm');

        if (typeof callback === 'function') {
            callback();
        }
    };

    global.transpiler.ports.sendToJs.subscribe(elmSubscription);
    global.transpiler.ports.sendToElm.send({
        routing: {
            urlPrefix: global.options.dev ? global.options.urlPrefix : '',
            content: content,
            version: global.options.elmVersion,
            envVariables: global.options.envVariables,
        }
    });
}

module.exports = {
    transpile,
};
