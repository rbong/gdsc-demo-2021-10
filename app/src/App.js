import * as React from 'react';

import axios from "axios";

import Box from '@mui/material/Box';
import CircularProgress from '@mui/material/CircularProgress';
import Container from '@mui/material/Container';
import Typography from '@mui/material/Typography';

import { useQuery } from 'react-query'

function App() {
  console.log(process.env);

  const { isLoading, error, data } = useQuery(
    "getMessage",
    () => axios.get(`${process.env.REACT_APP_API_URL}/message`)
  );

  return (
    <Container maxWidth="sm">
      <Box sx={{
        my: 4,
        display: "flex",
        flexDirection: "column",
        alignItems: "center"
      }}>
        <Typography variant="h4" component="h1" gutterBottom>
          Demo GDSC App
        </Typography>
        {
          isLoading
            ? <CircularProgress />
            : <Typography sx={{ mt: 6, mb: 3 }} color="text.secondary">
              Message of the day is {data.data.message}
            </Typography>
        }
      </Box>
    </Container>
  );
}

export default App;
