import {run} from '../../Formatting/formatter.mjs';
onmessage=event=>postMessage(run(event.data.source,event.data.kind,event.data.dialect));
