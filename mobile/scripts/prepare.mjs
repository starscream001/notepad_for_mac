import {existsSync} from 'node:fs';import {readFile,writeFile,mkdir,copyFile} from 'node:fs/promises';import {spawnSync} from 'node:child_process';
const platform=process.argv[2];if(!['android','ios'].includes(platform))throw Error('Use: node scripts/prepare.mjs android|ios');
const cap=(...args)=>{const r=spawnSync(process.execPath,['node_modules/@capacitor/cli/bin/capacitor',...args],{stdio:'inherit'});if(r.status!==0)throw Error('Capacitor failed');};
cap(existsSync(platform)?'sync':'add',platform);
const pkg=JSON.parse(await readFile('package.json','utf8')),version=pkg.version.split('-')[0],buildNumber=100001;
if(platform==='android'){
 const file='android/app/build.gradle';let s=await readFile(file,'utf8');s=s.replace(/versionCode \d+/,`versionCode ${buildNumber}`).replace(/versionName "[^"]+"/,`versionName "${pkg.version}"`);await writeFile(file,s);
 await mkdir('android/app/src/main/res/drawable',{recursive:true});await copyFile('../Resources/AppIcon.png','android/app/src/main/res/drawable/notepad_logo.png');
 const manifest='android/app/src/main/AndroidManifest.xml';s=await readFile(manifest,'utf8');s=s.replace('android:allowBackup="true"','android:allowBackup="false"');s=s.replace(/android:icon="[^"]+"/,'android:icon="@drawable/notepad_logo"').replace(/android:roundIcon="[^"]+"/,'android:roundIcon="@drawable/notepad_logo"');await writeFile(manifest,s);
}else{
 const icon=spawnSync('sips',['-z','1024','1024','../Resources/AppIcon.png','--out','ios/App/App/Assets.xcassets/AppIcon.appiconset/AppIcon-512@2x.png'],{stdio:'inherit'});if(icon.status!==0)throw Error('iOS icon generation failed');
 const project='ios/App/App.xcodeproj/project.pbxproj';let s=await readFile(project,'utf8');s=s.replace(/IPHONEOS_DEPLOYMENT_TARGET = [^;]+;/g,"IPHONEOS_DEPLOYMENT_TARGET = 16.0;");s=s.replace(/CURRENT_PROJECT_VERSION = [^;]+;/g,`CURRENT_PROJECT_VERSION = ${buildNumber};`).replace(/MARKETING_VERSION = [^;]+;/g,`MARKETING_VERSION = ${version};`);
 if(!s.includes('PrivacyInfo.xcprivacy')){
  s=s.replace('/* Begin PBXBuildFile section */','/* Begin PBXBuildFile section */\n\t\tAA0000000000000000000001 /* PrivacyInfo.xcprivacy in Resources */ = {isa = PBXBuildFile; fileRef = AA0000000000000000000002 /* PrivacyInfo.xcprivacy */; };');
  s=s.replace('/* Begin PBXFileReference section */','/* Begin PBXFileReference section */\n\t\tAA0000000000000000000002 /* PrivacyInfo.xcprivacy */ = {isa = PBXFileReference; lastKnownFileType = text.xml; path = PrivacyInfo.xcprivacy; sourceTree = "<group>"; };');
  s=s.replace('/* Info.plist */,','/* Info.plist */,\n\t\t\t\tAA0000000000000000000002 /* PrivacyInfo.xcprivacy */,');
  s=s.replace(/(isa = PBXResourcesBuildPhase;[\s\S]*?files = \()/,'$1\n\t\t\t\tAA0000000000000000000001 /* PrivacyInfo.xcprivacy in Resources */,');
 }
 await writeFile(project,s);await copyFile('PrivacyInfo.xcprivacy','ios/App/App/PrivacyInfo.xcprivacy');
}
console.log(`${platform}: Notepad Mobile ${pkg.version} (${buildNumber}) prepared`);
