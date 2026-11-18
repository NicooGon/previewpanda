// Crea o actualiza el comentario del entorno de preview (uno por PR, identificado por un marcador oculto).
// Uso desde actions/github-script:
//   const comentar = require(`${process.env.GITHUB_WORKSPACE}/scripts/comentario_pr.js`);
//   await comentar({ github, context, lines: ['...'] });
module.exports = async ({ github, context, lines }) => {
  const marker = '<!-- preview-panda -->';
  const body = [marker, '### Entorno de preview', '', ...lines].join('\n');
  const { owner, repo } = context.repo;
  const issue_number = context.issue.number;

  const comments = await github.paginate(github.rest.issues.listComments, { owner, repo, issue_number });
  const existing = comments.find(c => c.body?.includes(marker));

  if (existing) {
    await github.rest.issues.updateComment({ owner, repo, comment_id: existing.id, body });
  } else {
    await github.rest.issues.createComment({ owner, repo, issue_number, body });
  }
};
