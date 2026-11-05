const messages={
 unconfigured:['Вход будет доступен после настройки приложения разработчиком.','Sign-in will be available after the developer configures the app.'],
 signedOut:['Аккаунт не подключён. Заметки остаются на устройстве.','Not connected. Your notes stay on this device.'],
 starting:['Подготавливаем безопасный вход…','Preparing secure sign-in…'],
 waiting:['Скопируйте код и введите его на github.com/login/device. Подтвердите вход в браузере, затем вернитесь сюда.','Copy the code and enter it at github.com/login/device. Approve sign-in in your browser, then return here.'],
 connected:['Аккаунт подключён.','Account connected.'],signingOut:['Выходим из аккаунта…','Signing out…'],error:['Вход не завершён.','Sign-in did not complete.'],
 storage:['Не удалось открыть защищённое хранилище. На Linux нужен Secret Service или KWallet. Токен не сохраняется открытым текстом.','Secure storage is unavailable. Linux needs Secret Service or KWallet. Tokens are never saved as plaintext.'],
 unauthorized:['Доступ отозван или истёк. Войдите снова.','Access was revoked or expired. Sign in again.'],network:['Не удалось связаться с GitHub. Проверьте сеть и повторите.','Could not reach GitHub. Check your connection and retry.'],rate_limit:['GitHub временно ограничил запросы. Повторите позже.','GitHub is limiting requests. Try again later.'],
 access_denied:['Вход отклонён в браузере. Можно попробовать снова.','Sign-in was declined in the browser. You can try again.'],expired_token:['Время действия кода истекло. Начните вход заново.','The code expired. Start sign-in again.'],
 invalid_response:['GitHub вернул неожиданный ответ. Вход остановлен.','GitHub returned an unexpected response. Sign-in stopped.'],incorrect_client_credentials:['Нужно проверить регистрацию приложения GitHub.','The GitHub app registration needs checking.'],device_flow_disabled:['Разработчику нужно включить Device Flow в GitHub.','The developer needs to enable GitHub Device Flow.']
};
export function mountGitHubAccount({api,call,english,synchronize}){
 const $=id=>document.getElementById(id);let state={phase:'signedOut'};
 const t=(ru,en)=>english()?en:ru,phrase=key=>{const pair=messages[key]||messages.network;return pair[english()?1:0];};
 function render(value=state){
  state=value;const connected=!!state.profile,waiting=state.phase==='waiting',busy=['starting','signingOut'].includes(state.phase);
  $('github-heading').textContent='GitHub';$('github-status').textContent=connected?`@${state.profile.login}${state.profile.name?' · '+state.profile.name:''}`:phrase(state.phase);
  $('github-description').textContent=t('Синхронизация всех локальных заметок, включая закрытые, по кнопке. При конфликте сохраняются обе версии.','Synchronize all local notes, including closed notes, on demand. Conflicts keep both versions.');
  $('github-error').textContent=state.error?phrase(state.error):state.browserError?t('Откройте страницу GitHub кнопкой ниже.','Open the GitHub page using the button below.'):'';
  $('github-code').hidden=!waiting;$('github-code').value=waiting?state.userCode:'';
  for(const [id,ru,en,show]of [['github-sign-in','Войти через браузер','Sign in with browser',!connected&&!waiting],['github-copy','Копировать код','Copy code',waiting],['github-browser','Открыть GitHub','Open GitHub',waiting],['github-cancel','Отмена','Cancel',waiting||state.phase==='starting'],['github-sync','Синхронизировать','Synchronize',connected],['github-install-app','Разрешить доступ GitHub','Allow GitHub access',connected],['github-create-repo','Создать приватный репозиторий','Create private repository',connected],['github-profile','Профиль','Profile',connected],['github-refresh','Проверить вход','Check connection',connected],['github-sign-out','Выйти','Sign out',connected||state.phase==='error']]){
   $(id).textContent=t(ru,en);$(id).hidden=!show;$(id).disabled=busy&&id!=='github-cancel'||id==='github-sign-in'&&state.phase==='unconfigured';
  }
  $('github-copy').setAttribute('aria-label',t('Копировать код входа GitHub','Copy GitHub sign-in code'));
 }
 async function action(name){try{const result=await call(name);if(result?.phase)render(result);}catch{render({...state,error:'network'});}}
 for(const [id,name]of [['github-sign-in','githubStart'],['github-cancel','githubCancel'],['github-sign-out','githubDisconnect'],['github-refresh','githubRefresh'],['github-browser','githubBrowser'],['github-install-app','githubInstallApp'],['github-profile','githubProfile']])$(id).onclick=()=>action(name);
 $('github-copy').onclick=async()=>{await action('githubCopyCode');$('github-error').textContent=t('Код скопирован.','Code copied.');};
 $('github-sync').onclick=async()=>{const b=$('github-sync');b.disabled=true;$('github-error').textContent=t('Синхронизация…','Synchronizing…');try{const result=await synchronize($('github-repo').value.trim());$('github-error').textContent=result?t('Синхронизировано. Конфликтных копий: ','Synchronized. Conflict copies: ')+result.conflicts+(result.pending?t('. Новые правки отправятся в следующий раз.','. New edits will be sent next time.'):''):t('Отменено.','Cancelled.');}catch(e){const errors={remote_changed:t('Репозиторий изменился на другом устройстве. Повторите синхронизацию.','Repository changed on another device. Synchronize again.'),private_repository_required:t('Нужен приватный репозиторий в вашем аккаунте.','A private repository owned by you is required.'),invalid_snapshot:t('Снимок повреждён или превышает предел (1 МБ на заметку, 5 МБ всего).','Snapshot is invalid or exceeds limits (1 MB per note, 5 MB total).')};$('github-error').textContent=errors[e.message]||t('Синхронизация не завершена. Локальные заметки сохранены; проверьте сеть, вход и права GitHub.','Sync did not complete. Local notes are preserved; check network, sign-in and GitHub permissions.');}finally{b.disabled=false;}};
 $('github-create-repo').onclick=async()=>{
  const button=$('github-create-repo');button.disabled=true;
  try{const repo=await call('githubCreateRepository',$('github-repo').value.trim());if(repo)$('github-error').textContent=t('Создан приватный репозиторий: ','Private repository created: ')+repo.owner+'/'+repo.name+t('. Нажмите «Синхронизировать».','. Click Synchronize.');}
  catch(e){const errors={name_unavailable:t('Имя notepad-notes занято. Существующий репозиторий не изменён.','The name notepad-notes is unavailable. No existing repository was changed.'),permission_required:t('GitHub не дал разрешение на создание. Проверьте установку App и Repository creation.','GitHub denied creation. Check the App installation and Repository creation permission.')};$('github-error').textContent=errors[e.message]||t('Не удалось подтвердить создание. Проверьте репозитории на GitHub перед повтором.','Could not confirm creation. Check your repositories on GitHub before retrying.');}
  finally{button.disabled=false;}
 };
 api.onGitHubAccount(render);render();return {render,load:()=>action('githubStatus'),synchronize:()=>{if(state.profile)$('github-sync').click();}};
}
