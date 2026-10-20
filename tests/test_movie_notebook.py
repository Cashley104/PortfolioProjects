"""Execute notebook transformation cells with edge-case movie fixtures."""
import json
from pathlib import Path
import unittest
import pandas as pd

NOTEBOOK = Path(__file__).resolve().parents[1] / 'Movie Correlation Portfolio Project.ipynb'

class MovieNotebookTests(unittest.TestCase):
    def run_cell(self, index, frame):
        cell = json.loads(NOTEBOOK.read_text(encoding='utf-8'))['cells'][index]
        env = {'df': frame, 'pd': pd}
        exec(compile(''.join(cell['source']), str(NOTEBOOK), 'exec'), env)
        return env

    def test_missing_or_invalid_release_year_stays_unknown(self):
        frame = pd.DataFrame({'released': ['June 1, 2001 (USA)', None, 'Unknown']})
        result = self.run_cell(5, frame)['df']['yearcorrect']
        self.assertEqual(result.iloc[0], 2001)
        self.assertTrue(result.iloc[1:].isna().all())

    def test_category_encoding_does_not_mutate_source_frame(self):
        frame = pd.DataFrame({'company': pd.Series(['A', 'B'], dtype=object), 'budget': [1, 2]})
        original = frame.copy(deep=True)
        result = self.run_cell(14, frame)['df_numerized']
        pd.testing.assert_frame_equal(frame, original)
        self.assertTrue(pd.api.types.is_integer_dtype(result['company']))

if __name__ == '__main__':
    unittest.main()
