const C="ds-v21",A=["./","index.html","manifest.json","icon.svg","qr.svg","example-squares.jpg"];
self.addEventListener("install",e=>{e.waitUntil(caches.open(C).then(c=>c.addAll(A)));self.skipWaiting()});
self.addEventListener("activate",e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==C).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
self.addEventListener("fetch",e=>{const u=new URL(e.request.url);if(e.request.method!=="GET"||u.hostname.includes("espn.com"))return;
if(u.origin===location.origin){e.respondWith(fetch(e.request).then(r=>{const c=r.clone();caches.open(C).then(x=>x.put(e.request,c));return r}).catch(()=>caches.match(e.request).then(r=>r||caches.match("index.html"))));return}
e.respondWith(caches.match(e.request).then(r=>r||fetch(e.request).then(n=>{if(n.ok||n.type==="opaque"){const c=n.clone();caches.open(C).then(x=>x.put(e.request,c))}return n})))});
self.addEventListener("notificationclick",e=>{e.notification.close();e.waitUntil(clients.matchAll({type:"window",includeUncontrolled:true}).then(l=>l.length?l[0].focus():clients.openWindow("./")))});
self.addEventListener("push",e=>{let m={title:"Squares",body:""};try{m=e.data.json()}catch(_){if(e.data)m.body=e.data.text()}e.waitUntil(self.registration.showNotification(m.title,{body:m.body,tag:m.tag,icon:"icon.svg",badge:"icon.svg",renotify:true}))});
