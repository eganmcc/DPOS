import { createApp } from 'vue';
import { createPinia } from 'pinia';
import './style.css';
import App from './App.vue';
import router from './router';

const app = createApp(App);
// Safety net: a render error should never leave a permanent white screen. Log it
// (auth errors already redirect to login via the api client); other errors are
// surfaced in the console for diagnosis rather than silently blanking the app.
app.config.errorHandler = (err, _instance, info) => {
  // eslint-disable-next-line no-console
  console.error('[DCP] Unhandled Vue error:', info, err);
};
app.use(createPinia()).use(router).mount('#app');
