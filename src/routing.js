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

    let content = symfony.queryRouting(global.options);

    const elmSubscription = data => {
        utils.onSuccess('routing', data, () => {
            fs.writeIfChanged(global.options.elmRoot + '/Routing.elm', data.content);
        });

        global.transpiler.ports.sendToJs.unsubscribe(elmSubscription);

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
