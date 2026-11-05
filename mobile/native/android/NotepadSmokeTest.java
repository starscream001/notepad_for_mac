package io.github.starscream001.notepad.mobile;

import android.app.Instrumentation;
import android.graphics.Bitmap;
import android.graphics.Rect;
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.InputDevice;
import android.view.WindowInsets;
import android.webkit.WebView;
import androidx.test.core.app.ActivityScenario;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import static org.junit.Assert.*;

@RunWith(AndroidJUnit4.class)
public class NotepadSmokeTest {
    private final Instrumentation instrumentation=InstrumentationRegistry.getInstrumentation();
    private MainActivity activity;
    private WebView web;
    private String js(String script) throws Exception {
        CountDownLatch latch=new CountDownLatch(1);AtomicReference<String> value=new AtomicReference<>();
        instrumentation.runOnMainSync(()->web.evaluateJavascript(script,result->{value.set(result);latch.countDown();}));
        assertTrue("JavaScript callback timed out",latch.await(10,TimeUnit.SECONDS));return value.get();
    }
    private void waitFor(String expression) throws Exception {
        long until=SystemClock.uptimeMillis()+20000;
        while(SystemClock.uptimeMillis()<until){if("true".equals(js(expression)))return;SystemClock.sleep(100);}
        fail("Condition failed: "+expression);
    }
    private void tap(String selector) throws Exception {
        JSONObject r=new JSONObject(js("(()=>{const e=document.querySelector("+JSONObject.quote(selector)+");const r=e.getBoundingClientRect();return {x:r.left+Math.min(r.width,48)/2,y:r.top+Math.min(r.height,44)/2,w:innerWidth};})()"));
        int[] origin=new int[2];instrumentation.runOnMainSync(()->web.getLocationOnScreen(origin));
        float scale=web.getWidth()/(float)r.getDouble("w"),x=origin[0]+(float)r.getDouble("x")*scale,y=origin[1]+(float)r.getDouble("y")*scale;
        long now=SystemClock.uptimeMillis();MotionEvent down=MotionEvent.obtain(now,now,MotionEvent.ACTION_DOWN,x,y,0),up=MotionEvent.obtain(now,now+80,MotionEvent.ACTION_UP,x,y,0);
        down.setSource(InputDevice.SOURCE_TOUCHSCREEN);up.setSource(InputDevice.SOURCE_TOUCHSCREEN);
        instrumentation.getUiAutomation().injectInputEvent(down,true);SystemClock.sleep(80);instrumentation.getUiAutomation().injectInputEvent(up,true);down.recycle();up.recycle();SystemClock.sleep(200);
    }
    @Test public void android14TabletControlsPreviewCredentialsAndKeyboard() throws Exception {
        try(ActivityScenario<MainActivity> scenario=ActivityScenario.launch(MainActivity.class)){
            scenario.onActivity(a->{activity=a;web=a.getBridge().getWebView();});
            waitFor("document.querySelector('#save-state')?.textContent.includes('На устройстве') && !!document.querySelector('.cm-content')");
            // Capacitor native launch splash can still intercept touches after the DOM is ready.
            SystemClock.sleep(3500);instrumentation.waitForIdleSync();
            assertEquals("true",js("matchMedia('(min-width:840px)').matches"));
            tap("#syntax");waitFor("document.querySelector('#format-dialog').open");
            tap("#format-choices button:nth-child(3)");waitFor("!document.querySelector('#format-dialog').open && document.querySelector('#syntax').textContent.includes('Markdown')");
            tap("#preview-toggle");waitFor("document.querySelector('#format-dialog').open");tap("#format-choices button:first-child");
            waitFor("!document.querySelector('#preview').hidden && document.querySelector('#rendered').srcdoc.includes('<html')");
            tap("#preview-toggle");waitFor("document.querySelector('#preview').hidden");
            tap("#more");waitFor("document.querySelector('#menu-dialog').open");
            assertEquals("true",js("['undo','redo','find','format-open','preview-open','tabs-open','export-backup','github-open'].every(id=>!document.getElementById(id).disabled)"));
            tap("#github-open");waitFor("document.querySelector('#github-dialog').open && !document.querySelector('#github-start').disabled");
            js("document.querySelector('#github-dialog').close()");
            // Synthetic disposable credentials exercise the real Android Keystore bridge, never an account token.
            js("window.__credentialQA='pending';Capacitor.Plugins.NotepadCredentials.set({value:'FAKE_CREDENTIAL_QA'}).then(()=>Capacitor.Plugins.NotepadCredentials.get()).then(r=>window.__credentialQA=r.value==='FAKE_CREDENTIAL_QA'?'pass':'fail').catch(()=>window.__credentialQA='fail')");
            waitFor("window.__credentialQA==='pass'");
            String disk=activity.getSharedPreferences("notepad-secure",0).getString("github","");assertFalse("Plaintext credential leaked to disk",disk.contains("FAKE_CREDENTIAL_QA"));assertTrue(disk.contains(":"));
            js("Capacitor.Plugins.NotepadCredentials.remove()");
            tap(".cm-content");
            long until=SystemClock.uptimeMillis()+15000;boolean shown=false;
            while(SystemClock.uptimeMillis()<until){AtomicReference<Boolean> result=new AtomicReference<>(false);instrumentation.runOnMainSync(()->{WindowInsets insets=activity.getWindow().getDecorView().getRootWindowInsets();result.set(insets!=null&&insets.isVisible(WindowInsets.Type.ime()));});if(result.get()){shown=true;break;}SystemClock.sleep(100);}
            assertTrue("Software keyboard did not open",shown);SystemClock.sleep(700);
            JSONObject footer=new JSONObject(js("(()=>{const r=document.querySelector('footer').getBoundingClientRect();return {bottom:r.bottom,w:innerWidth,editor:document.querySelector('#editor').getBoundingClientRect().height};})()"));
            Rect visible=new Rect();int[] origin=new int[2];instrumentation.runOnMainSync(()->{activity.getWindow().getDecorView().getWindowVisibleDisplayFrame(visible);web.getLocationOnScreen(origin);});
            float footerBottom=origin[1]+(float)footer.getDouble("bottom")*web.getWidth()/(float)footer.getDouble("w");
            assertTrue("Keyboard overlaps footer: "+footerBottom+" > "+visible.bottom,footerBottom<=visible.bottom+4);assertTrue("Editor collapsed",footer.getDouble("editor")>=80);
            Bitmap shot=instrumentation.getUiAutomation().takeScreenshot();File output=new File(activity.getExternalFilesDir(null),"android14-tablet-keyboard.png");try(FileOutputStream stream=new FileOutputStream(output)){shot.compress(Bitmap.CompressFormat.PNG,100,stream);}
        }
    }
}
