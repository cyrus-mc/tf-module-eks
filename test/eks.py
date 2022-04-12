import subprocess
import unittest
import json


class WebIdentityTest(unittest.TestCase):

    def test_expected_thumbprints(self):
        """
        OIDC thumbprints tied back to EKS are expected by the aws-sdk when using OIDC in place of kiam.
        """
        with open("plan.json", "r") as f:
            json_object = json.loads(f.read())

            thumbprint_list: dict = \
                [a for a in json_object["configuration"]["root_module"]["module_calls"]["eks"]["module"]["resources"]
                 if a["address"] == "aws_iam_openid_connect_provider.this"][0]["expressions"]["thumbprint_list"]

            self.assertTrue("data.tls_certificate.eks.certificates[0].sha1_fingerprint" in thumbprint_list["references"])

    @classmethod
    def setUpClass(cls) -> None:
        cmd = ["terraform", "plan", "-out=tf.plan"]
        print(" ".join(cmd))
        subprocess.call(cmd)

        with open("plan.json", "w") as plan_json_file:
            cmd = ["terraform", "show", "-json", "tf.plan"]
            print(" ".join(cmd))
            subprocess.call(cmd, stdout=plan_json_file)

    def __init__(self, *args, **kwargs):
        super(WebIdentityTest, self).__init__(*args, **kwargs)


if __name__ == '__main__':
    unittest.main()
