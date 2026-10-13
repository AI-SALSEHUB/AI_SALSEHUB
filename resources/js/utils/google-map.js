let googleMapInitialized = !!(window.google && window.google.maps);
let googleMapResolveInitPromise;
let googleMapRejectInitPromise;
// This promise handles the initialization
// status of the google maps script.
const initGoogleMapPromise = new Promise((resolve, reject) => {
    googleMapResolveInitPromise = resolve;
    googleMapRejectInitPromise = reject;
});

function hasGoogleMaps() {
    return !!(window.google && window.google.maps);
}

function getGoogleMapScriptSrc() {
    if (process.env.MIX_GOOGLE_MAP_API_KEY) {
        const params = new URLSearchParams({
            key: process.env.MIX_GOOGLE_MAP_API_KEY,
            callback: "emitGoogleMapLoaded",
            libraries: "places",
        });

        return `https://maps.googleapis.com/maps/api/js?${params.toString()}`;
    }

    return process.env.MIX_GOOGLE_MAP_API_JS_URI;
}

function hasMissingApiKey(scriptSrc) {
    return !scriptSrc || /[?&]key=(&|$)/.test(scriptSrc);
}

export default function () {
    if (hasGoogleMaps()) {
        googleMapInitialized = true;
        googleMapResolveInitPromise(window.google);
        return initGoogleMapPromise;
    }
    // If Google Maps already is googleMapInitialized
    // the `initGoogleMapPromise` should get resolved
    // eventually.
    if (googleMapInitialized) return initGoogleMapPromise;

    googleMapInitialized = true;
    // The callback function is called by
    // the Google Maps script if it is
    // successfully loaded.
    window.emitGoogleMapLoaded = () => googleMapResolveInitPromise(window.google);

    // We inject a new script tag into
    // the `<head>` of our HTML to load
    // the Google Maps script.
    const scriptSrc = getGoogleMapScriptSrc();
    if (hasMissingApiKey(scriptSrc)) {
        googleMapRejectInitPromise(
            new Error(
                "Google Maps API key is missing. Set MIX_GOOGLE_MAP_API_KEY or MIX_GOOGLE_MAP_API_JS_URI and rebuild assets."
            )
        );
        return initGoogleMapPromise;
    }
    const script = document.createElement("script");
    script.async = true;
    script.defer = true;
    script.src = scriptSrc;
    script.onerror = googleMapRejectInitPromise;
    document.querySelector("head").appendChild(script);

    return initGoogleMapPromise;
}
