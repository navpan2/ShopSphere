"""Add version field to products

Revision ID: add_version_field
Revises: 5522d13c539c
Create Date: 2025-07-14 10:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "add_version_field"
down_revision: Union[str, Sequence[str], None] = "5522d13c539c"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add version column with default value
    op.add_column(
        "products",
        sa.Column("version", sa.Integer(), nullable=False, server_default="1"),
    )
    op.add_column(
        "products",
        sa.Column("updated_at", sa.DateTime(), server_default=sa.text("now()")),
    )


def downgrade() -> None:
    op.drop_column("products", "version")
    op.drop_column("products", "updated_at")
