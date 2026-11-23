import json
import unittest
import urllib.error

from unittest.mock import patch, MagicMock

from aiaf.model_client import (
    request_tool,
    validate_tool_request
)


class TestToolRequestValidation(unittest.TestCase):

    def test_valid_customer_request(self):

        request = {
            "ToolCode": "GetCustomerBalance",
            "CustomerCode": "CUST-1001"
        }

        self.assertEqual(
            validate_tool_request(request),
            request
        )

    def test_no_supported_tool(self):

        request = {
            "ToolCode": "NO_SUPPORTED_TOOL",
            "CustomerCode": ""
        }

        self.assertEqual(
            validate_tool_request(request),
            request
        )

    def test_invalid_requests(self):

        invalid_requests = {
            "Not an object": [],

            "Missing customer code": {
                "ToolCode": "GetCustomerBalance"
            },

            "Unexpected field": {
                "ToolCode": "GetCustomerBalance",
                "CustomerCode": "CUST-1001",
                "Authorized": True
            },

            "Unsupported tool": {
                "ToolCode": "DeleteCustomer",
                "CustomerCode": "CUST-1001"
            },

            "Invalid customer code": {
                "ToolCode": "GetCustomerBalance",
                "CustomerCode": "CUST-ABCD"
            },

            "Invalid customer type": {
                "ToolCode": "GetCustomerBalance",
                "CustomerCode": 1001
            },

            "Invalid tool type": {
                "ToolCode": 123,
                "CustomerCode": "CUST-1001"
            },

            "Unexpected customer code": {
                "ToolCode": "NO_SUPPORTED_TOOL",
                "CustomerCode": "CUST-1001"
            }
        }

        for name, request in invalid_requests.items():

            with self.subTest(name=name):

                with self.assertRaises(ValueError):

                    validate_tool_request(request)


class TestModelExecution(unittest.TestCase):

    def mock_provider_response(
        self,
        mock_urlopen,
        provider_response
    ):

        response = MagicMock()

        response.read.return_value = json.dumps(
            provider_response
        ).encode("utf-8")

        mock_urlopen.return_value.__enter__.return_value = (
            response
        )

    def provider_response(self):

        return {
            "done": True,
            "response": json.dumps({
                "ToolCode": "GetCustomerBalance",
                "CustomerCode": "CUST-1001"
            }),
            "prompt_eval_count": 192,
            "eval_count": 23,
            "load_duration": 6_000_000_000,
            "total_duration": 14_000_000_000,
            "prompt_eval_duration": 4_000_000_000,
            "eval_duration": 3_000_000_000
        }

    @patch("aiaf.model_client.urllib.request.urlopen")
    def test_successful_execution(self, mock_urlopen):

        self.mock_provider_response(
            mock_urlopen,
            self.provider_response()
        )

        result = request_tool("Review Northwind.")

        self.assertEqual(
            result["ExecutionStatus"], "SUCCEEDED"
        )

        self.assertEqual(
            result["ResponseValidationDecision"], "PASSED"
        )

        self.assertEqual(
            result["ToolRequest"]["CustomerCode"], "CUST-1001"
        )

        self.assertEqual(result["InputTokens"], 192)
        self.assertEqual(result["OutputTokens"], 23)

        self.assertEqual(result["ModelLoadDurationMs"], 6000)
        self.assertEqual(result["ServerDurationMs"], 14000)
        self.assertEqual(result["PromptEvalDurationMs"], 4000)
        self.assertEqual(result["OutputEvalDurationMs"], 3000)

        self.assertIsNone(result["ErrorCode"])
        self.assertIsNone(result["InputCost"])
        self.assertIsNone(result["OutputCost"])
        self.assertIsNone(result["OtherCost"])

        self.assertEqual(result["CostBasis"], "UNAVAILABLE")

        self.assertIsNotNone(result["CompletedAt"])
        self.assertGreaterEqual(result["DurationMs"], 0)

        mock_urlopen.assert_called_once()

    @patch("aiaf.model_client.urllib.request.urlopen")
    def test_invalid_model_output(self, mock_urlopen):

        response = self.provider_response()
        response["response"] = "This is not JSON."

        self.mock_provider_response(mock_urlopen, response)

        result = request_tool("Review Northwind.")

        self.assertEqual(
            result["ExecutionStatus"], "SUCCEEDED"
        )

        self.assertEqual(
            result["ResponseValidationDecision"], "FAILED"
        )

        self.assertEqual(
            result["ErrorCode"], "INVALID_MODEL_OUTPUT"
        )

        self.assertIsNone(result["ToolRequest"])

        # Invalid output does not erase model consumption.
        self.assertEqual(result["InputTokens"], 192)
        self.assertEqual(result["OutputTokens"], 23)

    @patch("aiaf.model_client.urllib.request.urlopen")
    def test_incomplete_model_response(self, mock_urlopen):

        response = self.provider_response()
        response["done"] = False

        self.mock_provider_response(mock_urlopen, response)

        result = request_tool("Review Northwind.")

        self.assertEqual(result["ExecutionStatus"], "FAILED")

        self.assertEqual(
            result["ResponseValidationDecision"],
            "NOT_EVALUATED"
        )

        self.assertEqual(
            result["ErrorCode"], "INCOMPLETE_MODEL_RESPONSE"
        )

        self.assertIsNone(result["ToolRequest"])

    @patch("aiaf.model_client.urllib.request.urlopen")
    def test_connection_failure(self, mock_urlopen):

        mock_urlopen.side_effect = urllib.error.URLError(
            "Connection refused"
        )

        result = request_tool("Review Northwind.")

        self.assertEqual(result["ExecutionStatus"], "FAILED")

        self.assertEqual(
            result["ErrorCode"], "MODEL_CONNECTION_ERROR"
        )

        self.assertEqual(
            result["ResponseValidationDecision"],
            "NOT_EVALUATED"
        )

        self.assertIsNone(result["InputTokens"])
        self.assertIsNone(result["OutputTokens"])
        self.assertIsNone(result["ToolRequest"])

    @patch("aiaf.model_client.urllib.request.urlopen")
    def test_model_timeout(self, mock_urlopen):

        mock_urlopen.side_effect = TimeoutError()

        result = request_tool("Review Northwind.")

        self.assertEqual(result["ExecutionStatus"], "TIMEOUT")
        self.assertEqual(result["ErrorCode"], "MODEL_TIMEOUT")

        self.assertEqual(
            result["ResponseValidationDecision"],
            "NOT_EVALUATED"
        )

        self.assertIsNone(result["ToolRequest"])

    @patch("aiaf.model_client.urllib.request.urlopen")
    def test_http_error(self, mock_urlopen):

        mock_urlopen.side_effect = urllib.error.HTTPError(
            "http://localhost:11434/api/generate",
            503,
            "Service Unavailable",
            None,
            None
        )

        result = request_tool("Review Northwind.")

        self.assertEqual(result["ExecutionStatus"], "FAILED")
        self.assertEqual(result["ErrorCode"], "MODEL_HTTP_ERROR")
        self.assertIsNone(result["ToolRequest"])

    @patch("aiaf.model_client.urllib.request.urlopen")
    def test_invalid_provider_response(self, mock_urlopen):

        response = MagicMock()
        response.read.return_value = b"Not valid JSON"

        mock_urlopen.return_value.__enter__.return_value = (
            response
        )

        result = request_tool("Review Northwind.")

        self.assertEqual(result["ExecutionStatus"], "FAILED")

        self.assertEqual(
            result["ErrorCode"], "INVALID_PROVIDER_RESPONSE"
        )

        self.assertIsNone(result["ToolRequest"])


if __name__ == "__main__":
    unittest.main()