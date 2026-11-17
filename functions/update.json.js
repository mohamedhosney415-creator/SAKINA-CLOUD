const SUPABASE_URL = 'https://gjvqewyuqkmgvcpzsssc.supabase.co';
const SUPABASE_PUBLISHABLE_KEY = 'sb_publishable_hyC9KFsTSkHeKMn-HcxnnQ_5KgCZMLQ';
const FALLBACK_APK = 'https://github.com/mohamedhosney415-creator/SAKINA-CLOUD/releases/latest/download/app-release.apk';

export async function onRequestGet() {
  const headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store, max-age=0',
    'X-Content-Type-Options': 'nosniff',
  };

  try {
    const response = await fetch(
      SUPABASE_URL + '/rest/v1/rpc/get_public_app_update',
      {
        method: 'POST',
        headers: {
          apikey: SUPABASE_PUBLISHABLE_KEY,
          Authorization: 'Bearer ' + SUPABASE_PUBLISHABLE_KEY,
          'Content-Type': 'application/json',
        },
        body: '{}',
      },
    );
    if (!response.ok) {
      return new Response(JSON.stringify({
        latestVersion: '',
        latestBuild: 0,
        apkUrl: FALLBACK_APK,
        minimumVersion: '',
        notes: '',
        showUpdate: false,
        autoCheck: false,
        mandatory: false,
      }), { status: 503, headers });
    }
    const settings = await response.json();
    if (!settings) throw new Error('Update settings are not configured.');
    return new Response(JSON.stringify(settings), { status: 200, headers });
  } catch (_) {
    return new Response(JSON.stringify({
      latestVersion: '',
      latestBuild: 0,
      apkUrl: FALLBACK_APK,
      minimumVersion: '',
      notes: '',
      showUpdate: false,
      autoCheck: false,
      mandatory: false,
    }), { status: 503, headers });
  }
}
