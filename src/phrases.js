// Short, present-tense phrases aligned with Kristin Neff's self-compassion
// framework. Deliberately not affirmations ("you are worthy") — those can
// backfire for people with low self-esteem.
export const phrases = [
  'I can be gentle',
  'This too will pass',
  'May I be at ease',
  'I am safe right now',
  'Begin again',
  'Steady as breath',
  'May I find peace',
  'Soft and slow',
  'I am whole',
];

export const randomPhrase = () => phrases[Math.floor(Math.random() * phrases.length)];
