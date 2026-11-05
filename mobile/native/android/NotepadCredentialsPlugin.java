package io.github.starscream001.notepad.mobile;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

@CapacitorPlugin(name="NotepadCredentials")
public class NotepadCredentialsPlugin extends Plugin {
    private static final String ALIAS="notepad.github.credentials.v1";
    private SharedPreferences preferences(){return getContext().getSharedPreferences("notepad-secure",Context.MODE_PRIVATE);}
    private SecretKey key(boolean create) throws Exception {
        KeyStore store=KeyStore.getInstance("AndroidKeyStore");store.load(null);
        if(store.containsAlias(ALIAS))return (SecretKey)store.getKey(ALIAS,null);
        if(!create)throw new IllegalStateException("Missing encryption key");
        KeyGenerator generator=KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_ENCRYPT|KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setRandomizedEncryptionRequired(true).build());return generator.generateKey();
    }
    @PluginMethod public synchronized void get(PluginCall call){
        try{String encrypted=preferences().getString("github",null);JSObject result=new JSObject();
            if(encrypted==null){result.put("value",org.json.JSONObject.NULL);call.resolve(result);return;}
            String[] pieces=encrypted.split(":");if(pieces.length!=2||encrypted.length()>32768)throw new IllegalStateException();
            Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.DECRYPT_MODE,key(false),new GCMParameterSpec(128,Base64.decode(pieces[0],Base64.NO_WRAP)));
            result.put("value",new String(cipher.doFinal(Base64.decode(pieces[1],Base64.NO_WRAP)),StandardCharsets.UTF_8));call.resolve(result);
        }catch(Exception e){call.reject("Secure storage unavailable","secure_storage");}
    }
    @PluginMethod public synchronized void set(PluginCall call){
        try{String value=call.getString("value");if(value==null||value.length()>16384)throw new IllegalArgumentException();
            Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");cipher.init(Cipher.ENCRYPT_MODE,key(true));
            String encrypted=Base64.encodeToString(cipher.getIV(),Base64.NO_WRAP)+":"+Base64.encodeToString(cipher.doFinal(value.getBytes(StandardCharsets.UTF_8)),Base64.NO_WRAP);
            if(!preferences().edit().putString("github",encrypted).commit())throw new IllegalStateException();call.resolve();
        }catch(Exception e){call.reject("Secure storage unavailable","secure_storage");}
    }
    @PluginMethod public synchronized void remove(PluginCall call){
        if(preferences().edit().remove("github").commit())call.resolve();else call.reject("Secure storage unavailable","secure_storage");
    }
}
