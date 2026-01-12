// Placeholder service - Manager will regenerate config when deployments are made
export default {
  async fetch(request) {
    return new Response('Gridiron workerd is running. Deploy services via POST /activate', {status: 200});
  }
}
