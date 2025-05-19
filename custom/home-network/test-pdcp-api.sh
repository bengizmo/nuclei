#!/bin/bash
# Test PDCP API key functionality

echo "Testing PDCP API key..."

# Test with a simple AI query
PDCP_API_KEY="b1e5b881-f0b7-4cf8-95b3-05de6b978052"

# Run nuclei with AI to test the API key
echo "Testing AI template generation..."
nuclei -ai "detect exposed synology nas panels" -silent -json -o test-ai-output.json

if [ -f test-ai-output.json ]; then
    echo "✅ API key is valid - template generation successful"
    echo "Generated template output:"
    cat test-ai-output.json | head -5
    rm test-ai-output.json
else
    echo "❌ API key test failed"
fi