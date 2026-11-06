export const sources = {
  division: {label: 'Mathematics Developmental Continuum · Mental division', url: 'https://www.smartvic.com/teacher/mdc/structure/st35mentaldiv.html'},
  addition: {label: 'Math is Fun · Addition tips', url: 'https://www.mathsisfun.com/numbers/addition-tips-tricks.html'},
  mental: {label: 'Alloprof · Mental math', url: 'https://www.alloprof.qc.ca/en/students/vl/mathematics/mental-math-m1380'},
  tricks: {label: 'Daryl Stephens, ETSU · Mental Math Tricks and More (PDF)', url: 'https://faculty.etsu.edu/stephen/TNADE/mentalmath.pdf'},
};

export interface Technique {
  title: string;
  when: string;
  tip: string;
  example: string;
  steps: string[];
  question: string;
  solution: string;
  source: keyof typeof sources;
}

export const lessons: {id: string; symbol: string; title: string; intro: string; techniques: Technique[]}[] = [
  {id: 'addition', symbol: '+', title: 'Addition', intro: 'Look for a ten, a hundred, or a double.', techniques: [
    {title: 'Make a round number', when: 'One number is just below a ten.',
      tip: 'Move a small amount from one addend to the other. The total stays the same.',
      example: '38 + 27', steps: ['Move 2 from 27 to 38.', '40 + 25 = 65'],
      question: '59 + 26', solution: '60 + 25 = 85', source: 'addition'},
    {title: 'Round, then correct', when: 'A number is near a hundred.',
      tip: 'Round up, add, then subtract the extra.',
      example: '198 + 46', steps: ['200 + 46 = 246', '246 − 2 = 244'],
      question: '297 + 58', solution: '300 + 58 − 3 = 355', source: 'addition'},
    {title: 'Use a near double', when: 'The numbers are one apart.',
      tip: 'Double the smaller number, then add one.',
      example: '36 + 37', steps: ['36 + 36 = 72', '72 + 1 = 73'],
      question: '48 + 49', solution: '48 × 2 + 1 = 97', source: 'addition'},
  ]},
  {id: 'subtraction', symbol: '−', title: 'Subtraction', intro: 'Keep the difference, simplify the numbers.', techniques: [
    {title: 'Subtract a round number', when: 'The number you subtract is near a ten.',
      tip: 'If you subtract too much, add the extra back.',
      example: '84 − 29', steps: ['84 − 30 = 54', '54 + 1 = 55'],
      question: '143 − 59', solution: '143 − 60 + 1 = 84', source: 'mental'},
    {title: 'Shift both numbers', when: 'Rounding the second number removes borrowing.',
      tip: 'Add the same amount to both numbers. Their difference is unchanged.',
      example: '152 − 98', steps: ['Add 2 to both numbers.', '154 − 100 = 54'],
      question: '231 − 197', solution: '234 − 200 = 34', source: 'tricks'},
    {title: 'Subtract in parts', when: 'There is no convenient nearby round number.',
      tip: 'Take away tens first, then units.',
      example: '87 − 34', steps: ['87 − 30 = 57', '57 − 4 = 53'],
      question: '126 − 43', solution: '126 − 40 − 3 = 83', source: 'mental'},
  ]},
  {id: 'multiplication', symbol: '×', title: 'Multiplication', intro: 'Build a hard product from easier ones.', techniques: [
    {title: 'Split a factor', when: 'You know the smaller multiplication facts.',
      tip: 'Multiply each part, then add the products.',
      example: '16 × 7', steps: ['10 × 7 = 70; 6 × 7 = 42', '70 + 42 = 112'],
      question: '14 × 8', solution: '80 + 32 = 112', source: 'mental'},
    {title: 'Use a nearby multiple', when: 'Multiplying by 9, 19, or 99.',
      tip: 'Multiply by 10, 20, or 100, then subtract one copy.',
      example: '19 × 6', steps: ['20 × 6 = 120', '120 − 6 = 114'],
      question: '99 × 7', solution: '700 − 7 = 693', source: 'tricks'},
    {title: 'Halve and double', when: 'An even factor is paired with 5, 25, or 50.',
      tip: 'Halve one factor and double the other. Repeat while it helps; the product stays unchanged.',
      example: '24 × 25', steps: ['12 × 50', '6 × 100 = 600'],
      question: '16 × 25', solution: '8 × 50 = 4 × 100 = 400', source: 'tricks'},
  ]},
  {id: 'division', symbol: '÷', title: 'Division', intro: 'Think in factors and easy chunks.', techniques: [
    {title: 'Reverse a multiplication', when: 'The dividend looks like a known product.',
      tip: 'Ask what times the divisor gives the dividend.',
      example: '72 ÷ 8', steps: ['8 × ? = 72', '8 × 9 = 72, so the answer is 9.'],
      question: '96 ÷ 12', solution: '12 × 8 = 96, so 96 ÷ 12 = 8.', source: 'division'},
    {title: 'Divide in stages', when: 'The divisor has easy factors.',
      tip: 'For division by 12, divide by 3 then 4. Use factors, not a sum: dividing by 3 then 4 is not dividing by 7.',
      example: '144 ÷ 12', steps: ['144 ÷ 3 = 48', '48 ÷ 4 = 12'],
      question: '168 ÷ 12', solution: '168 ÷ 3 = 56; 56 ÷ 4 = 14.', source: 'division'},
    {title: 'Scale to divide by 5 or 25', when: 'A divisor can become 10 or 100.',
      tip: 'Multiply both numbers by the same amount. For ÷5, double both; for ÷25, multiply both by 4.',
      example: '175 ÷ 25', steps: ['(175 × 4) ÷ (25 × 4)', '700 ÷ 100 = 7'],
      question: '235 ÷ 5', solution: '470 ÷ 10 = 47', source: 'division'},
  ]},
];
